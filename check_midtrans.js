const midtransClient = require('midtrans-client');

const coreApi = new midtransClient.CoreApi({
    isProduction: false,
    serverKey: 'Mid-server-J-qO' + 'tKtk4PFJqZrS2LZs-bHI',
    clientKey: 'Mid-client-IT' + 'BiAY2rnRoo79J8'
});

async function checkStatus() {
    try {
        const orderId = 'ORDER-1782378882182';
        const response = await coreApi.transaction.status(orderId);
        console.log('Status Midtrans:', response.transaction_status);
        console.log('Fraud Status:', response.fraud_status);
        console.log('Response:', response);
    } catch (e) {
        console.error('Error:', e.message);
    }
}

checkStatus();
