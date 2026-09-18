const crypto = require('node:crypto');
const { supabaseRpc } = require('./_supabase');

function json(res, status, body) {
  res.status(status).setHeader('Content-Type', 'application/json').send(body);
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') return json(res, 405, { error: 'Method not allowed.' });
  const rawBody = typeof req.body === 'string' ? req.body : JSON.stringify(req.body || {});
  const signature = String(req.headers['x-razorpay-signature'] || '');
  const expected = crypto.createHmac('sha256', process.env.RAZORPAY_WEBHOOK_SECRET || '')
    .update(rawBody).digest('hex');
  if (signature.length !== expected.length
    || !crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
    return json(res, 401, { error: 'Invalid webhook signature.' });
  }
  try {
    const event = JSON.parse(rawBody);
    const payment = event.payload?.payment?.entity || {};
    const orderId = payment.order_id || event.payload?.order?.entity?.id;
    const status = event.event === 'payment.captured' ? 'paid'
      : event.event === 'refund.processed' ? 'refunded' : 'failed';
    const result = await supabaseRpc('verify_payment_webhook', {
      p_provider: 'razorpay',
      p_provider_event_id: event.id || crypto.createHash('sha256').update(rawBody).digest('hex'),
      p_provider_order_id: orderId,
      p_event_type: event.event || 'unknown',
      p_payment_status: status,
      p_provider_payload: event
    });
    return json(res, 200, { accepted: true, eventId: result });
  } catch (error) {
    console.error('Payment webhook error:', error);
    return json(res, 400, { error: 'Webhook could not be processed.' });
  }
};
