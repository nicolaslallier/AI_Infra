#!/usr/bin/env python3
"""
Generate test traces for Tempo
This script sends sample traces to Tempo using the OTLP protocol.
"""

import os
import time
import random
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.trace import Status, StatusCode

# Configure the tracer
resource = Resource(attributes={
    "service.name": "test-service",
    "service.version": "1.0.0",
    "deployment.environment": "development"
})

# Create OTLP exporter pointing to Tempo
otlp_exporter = OTLPSpanExporter(
    endpoint="http://tempo:4318/v1/traces",
    # For external access, use: http://localhost/monitoring/tempo/v1/traces
)

# Set up the tracer provider
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

# Add the OTLP exporter
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)


def generate_user_request_trace():
    """Generate a sample user request trace with multiple spans"""
    with tracer.start_as_current_span("user-request") as parent_span:
        parent_span.set_attribute("http.method", "GET")
        parent_span.set_attribute("http.url", "/api/users")
        parent_span.set_attribute("http.status_code", 200)
        parent_span.set_attribute("user.id", random.randint(1, 1000))
        
        # Simulate authentication check
        with tracer.start_as_current_span("authenticate") as auth_span:
            auth_span.set_attribute("auth.method", "jwt")
            time.sleep(random.uniform(0.01, 0.05))
            auth_span.set_status(Status(StatusCode.OK))
        
        # Simulate database query
        with tracer.start_as_current_span("database-query") as db_span:
            db_span.set_attribute("db.system", "postgresql")
            db_span.set_attribute("db.statement", "SELECT * FROM users WHERE id = ?")
            time.sleep(random.uniform(0.05, 0.15))
            db_span.set_status(Status(StatusCode.OK))
        
        # Simulate cache check
        with tracer.start_as_current_span("cache-check") as cache_span:
            cache_span.set_attribute("cache.system", "redis")
            cache_span.set_attribute("cache.hit", random.choice([True, False]))
            time.sleep(random.uniform(0.005, 0.02))
            cache_span.set_status(Status(StatusCode.OK))
        
        parent_span.set_status(Status(StatusCode.OK))


def generate_order_processing_trace():
    """Generate a sample order processing trace"""
    with tracer.start_as_current_span("order-processing") as parent_span:
        parent_span.set_attribute("order.id", random.randint(1000, 9999))
        parent_span.set_attribute("order.amount", round(random.uniform(10, 500), 2))
        
        # Validate order
        with tracer.start_as_current_span("validate-order") as validate_span:
            time.sleep(random.uniform(0.02, 0.05))
            validate_span.set_status(Status(StatusCode.OK))
        
        # Process payment
        with tracer.start_as_current_span("process-payment") as payment_span:
            payment_span.set_attribute("payment.method", "credit_card")
            payment_span.set_attribute("payment.gateway", "stripe")
            time.sleep(random.uniform(0.1, 0.3))
            payment_span.set_status(Status(StatusCode.OK))
        
        # Update inventory
        with tracer.start_as_current_span("update-inventory") as inventory_span:
            inventory_span.set_attribute("inventory.item", f"ITEM-{random.randint(1, 100)}")
            time.sleep(random.uniform(0.05, 0.1))
            inventory_span.set_status(Status(StatusCode.OK))
        
        # Send notification
        with tracer.start_as_current_span("send-notification") as notif_span:
            notif_span.set_attribute("notification.type", "email")
            notif_span.set_attribute("notification.recipient", f"user{random.randint(1, 1000)}@example.com")
            time.sleep(random.uniform(0.02, 0.08))
            notif_span.set_status(Status(StatusCode.OK))
        
        parent_span.set_status(Status(StatusCode.OK))


def generate_error_trace():
    """Generate a trace with an error"""
    with tracer.start_as_current_span("failed-request") as parent_span:
        parent_span.set_attribute("http.method", "POST")
        parent_span.set_attribute("http.url", "/api/data")
        
        with tracer.start_as_current_span("database-operation") as db_span:
            db_span.set_attribute("db.system", "postgresql")
            db_span.set_attribute("db.statement", "INSERT INTO data VALUES (?)")
            time.sleep(random.uniform(0.01, 0.03))
            
            # Simulate an error
            db_span.set_status(
                Status(StatusCode.ERROR, "Connection timeout")
            )
            db_span.record_exception(Exception("Database connection timeout"))
        
        parent_span.set_attribute("http.status_code", 500)
        parent_span.set_status(Status(StatusCode.ERROR, "Request failed"))


def main():
    """Generate various traces continuously"""
    print("🚀 Starting trace generator for Tempo...")
    print(f"📡 Sending traces to: {otlp_exporter._endpoint}")
    print("⏸️  Press Ctrl+C to stop\n")
    
    trace_count = 0
    
    try:
        while True:
            # Generate different types of traces with weighted probabilities
            rand = random.random()
            
            if rand < 0.5:  # 50% user requests
                generate_user_request_trace()
                trace_type = "user-request"
            elif rand < 0.85:  # 35% order processing
                generate_order_processing_trace()
                trace_type = "order-processing"
            else:  # 15% errors
                generate_error_trace()
                trace_type = "error"
            
            trace_count += 1
            print(f"✅ Generated trace #{trace_count}: {trace_type}")
            
            # Wait between traces
            time.sleep(random.uniform(1, 3))
            
    except KeyboardInterrupt:
        print(f"\n\n🛑 Stopping trace generator. Generated {trace_count} traces.")
        print("⏳ Flushing remaining traces...")
        # Force flush remaining traces
        trace.get_tracer_provider().force_flush()
        print("✅ Done!")


if __name__ == "__main__":
    main()

