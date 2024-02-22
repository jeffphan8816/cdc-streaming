import faker
import psycopg2
import random
from datetime import datetime

# Create a Faker instance
fake = faker.Faker()


def generate_transaction():
    user = fake.simple_profile()

    return {
        "transaction_id": fake.uuid4(),
        "userId": user["username"],
        "timestamp": datetime.utcnow().timestamp(),
        "currency": random.choice(['USD', 'EUR', 'GBP']),
        "amount": round(random.uniform(10, 1000), 2),
        "country": fake.country(),
        "city": fake.city(),
        "ipAddress": fake.ipv4(),
        "merchantName": fake.company(),
        "paymentMethod": random.choice(['Visa', 'Mastercard', 'Paypal', 'Bitcoin', 'Apple Pay', 'Google Pay']),
        "voucherCode": random.choice(['', 'DISCOUNT10', 'DISCOUNT20', 'DISCOUNT50']),
        "affiliateId": fake.uuid4()
    }


def create_table(conn):
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS transactions (
                transaction_id UUID PRIMARY KEY,
                user_id VARCHAR(255),
                timestamp TIMESTAMP,
                currency VARCHAR(3),
                amount DECIMAL,
                country VARCHAR(255),
                city VARCHAR(255),
                ipAddress VARCHAR(15),
                merchant_name VARCHAR(255),
                payment_method VARCHAR(255),
                voucher_code VARCHAR(255),
                affiliateId UUID
            )
        """)
        conn.commit()


if __name__ == "__main__":
    conn = psycopg2.connect(
        host="localhost",
        database="financial_db",
        user="postgres",
        password="postgres"
    )

    create_table(conn)

    with conn.cursor() as cur:
        for _ in range(1000):
            transaction = generate_transaction()
            cur.execute("""
                INSERT INTO transactions (
                    transaction_id, user_id, timestamp, currency, amount, country,
                    city, ipAddress, merchant_name, payment_method, voucher_code, affiliateId
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s )
            """, (
                transaction["transaction_id"], transaction["userId"],
                datetime.fromtimestamp(transaction["timestamp"]).strftime('%Y-%m-%d %H:%M:%S'),
                transaction["currency"], transaction["amount"], transaction["country"],
                transaction["city"], transaction["ipAddress"], transaction["merchantName"],
                transaction["paymentMethod"], transaction["voucherCode"], transaction["affiliateId"]
            )
                        )
        conn.commit()
