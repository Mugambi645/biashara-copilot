package rabbitmq

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

// Exchange and routing key constants — the single source of truth
// for all events in the system.
const (
	Exchange              = "biashara.events"
	EventSaleRecorded     = "sale.recorded"
	EventStockLow         = "stock.low"
	EventStockUpdated     = "stock.updated"
	EventForecastReady    = "forecast.ready"
	EventReceiptUploaded  = "receipt.uploaded"
	EventReceiptProcessed = "receipt.processed"
	EventPaymentOverdue   = "payment.overdue"
	EventMarginDrop       = "margin.drop"
	EventAnomalyDetected  = "anomaly.detected"
	EventAlertCreated     = "alert.created"
)

type Client struct {
	conn    *amqp.Connection
	url     string
	channel *amqp.Channel
}

type Message struct {
	EventType string          `json:"event_type"`
	TenantID  string          `json:"tenant_id"`
	BranchID  string          `json:"branch_id,omitempty"`
	Payload   json.RawMessage `json:"payload"`
	Timestamp time.Time       `json:"timestamp"`
}

func NewClient(url string) (*Client, error) {
	c := &Client{url: url}
	if err := c.connect(); err != nil {
		return nil, err
	}
	return c, nil
}

func (c *Client) connect() error {
	conn, err := amqp.Dial(c.url)
	if err != nil {
		return fmt.Errorf("amqp dial: %w", err)
	}

	ch, err := conn.Channel()
	if err != nil {
		conn.Close()
		return fmt.Errorf("open channel: %w", err)
	}

	// Declare topic exchange — durable so it survives restarts
	if err := ch.ExchangeDeclare(
		Exchange, "topic", true, false, false, false, nil,
	); err != nil {
		ch.Close()
		conn.Close()
		return fmt.Errorf("declare exchange: %w", err)
	}

	c.conn = conn
	c.channel = ch
	return nil
}

// Publish sends an event to the exchange with the given routing key.
func (c *Client) Publish(ctx context.Context, routingKey, tenantID, branchID string, payload any) error {
	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal payload: %w", err)
	}

	msg := Message{
		EventType: routingKey,
		TenantID:  tenantID,
		BranchID:  branchID,
		Payload:   data,
		Timestamp: time.Now().UTC(),
	}

	body, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("marshal message: %w", err)
	}

	return c.channel.PublishWithContext(ctx, Exchange, routingKey, false, false, amqp.Publishing{
		ContentType:  "application/json",
		DeliveryMode: amqp.Persistent,
		Body:         body,
		Timestamp:    time.Now(),
	})
}

// Subscribe declares a queue bound to the exchange and starts consuming.
// pattern supports AMQP wildcards: "sale.*", "stock.#", etc.
func (c *Client) Subscribe(queueName, pattern string, handler func(Message) error) error {
	q, err := c.channel.QueueDeclare(queueName, true, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("declare queue %s: %w", queueName, err)
	}

	if err := c.channel.QueueBind(q.Name, pattern, Exchange, false, nil); err != nil {
		return fmt.Errorf("bind queue: %w", err)
	}

	msgs, err := c.channel.Consume(q.Name, "", false, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("consume: %w", err)
	}

	go func() {
		for d := range msgs {
			var m Message
			if err := json.Unmarshal(d.Body, &m); err != nil {
				log.Printf("[rabbitmq] bad message on %s: %v", queueName, err)
				d.Nack(false, false)
				continue
			}

			if err := handler(m); err != nil {
				log.Printf("[rabbitmq] handler error on %s: %v", queueName, err)
				d.Nack(false, true) // requeue once
			} else {
				d.Ack(false)
			}
		}
	}()

	log.Printf("[rabbitmq] subscribed queue=%s pattern=%s", queueName, pattern)
	return nil
}

func (c *Client) Close() {
	if c.channel != nil {
		c.channel.Close()
	}
	if c.conn != nil {
		c.conn.Close()
	}
}