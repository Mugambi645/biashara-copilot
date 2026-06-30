import rabbitmq

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

