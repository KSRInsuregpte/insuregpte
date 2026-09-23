const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, supabaseRpc } = require('./_supabase');

function json(res, status, body) {
  res.status(status).setHeader('Content-Type', 'application/json').send(body);
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') return json(res, 405, { error: 'Method not allowed.' });
  const token = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  const clientId = String(req.headers['x-insuregpte-client-id'] || '');
  if (!token) return json(res, 401, { error: 'Authentication is required.' });
  if (!clientId) return json(res, 401, { error: 'Active login verification is required.' });
  try {
    const rows = await supabaseRpc(
      'create_payment_order',
      { p_provider: 'razorpay' },
      token,
      { 'x-insuregpte-client-id': clientId }
    );
    const order = Array.isArray(rows) ? rows[0] : rows;
    if (!order?.order_id || !order.amount || order.currency_code !== 'INR') {
      throw new Error('The server did not return a valid payment order.');
    }
    if (!process.env.RAZORPAY_KEY_ID || !process.env.RAZORPAY_KEY_SECRET) {
      throw new Error('Razorpay is not configured.');
    }
    const razorpayResponse = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${process.env.RAZORPAY_KEY_ID}:${process.env.RAZORPAY_KEY_SECRET}`).toString('base64')}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        amount: Math.round(Number(order.amount) * 100),
        currency: order.currency_code,
        receipt: order.order_id
      })
    });
    const razorpayOrder = await razorpayResponse.json();
    if (!razorpayResponse.ok || !razorpayOrder.id) {
      throw new Error('Razorpay order creation failed.');
    }
    await supabaseRpc('set_payment_provider_order', {
      p_order_id: order.order_id,
      p_provider_order_id: razorpayOrder.id
    });
    return json(res, 200, {
      orderId: order.order_id,
      providerOrderId: razorpayOrder.id,
      amount: razorpayOrder.amount,
      currency: razorpayOrder.currency,
      keyId: process.env.RAZORPAY_KEY_ID
    });
  } catch (error) {
    console.error('Payment order error:', error);
    return json(res, 400, { error: error.message || 'Unable to start checkout.' });
  }
};
