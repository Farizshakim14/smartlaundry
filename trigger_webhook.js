fetch('http://103.150.226.111:3000/midtrans-webhook', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    "order_id": "ORDER-1782378882182",
    "transaction_status": "settlement",
    "fraud_status": "accept"
  })
}).then(res => res.json()).then(console.log).catch(console.error);
