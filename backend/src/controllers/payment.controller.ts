import { Response } from 'express';
import prisma from '../utils/prisma';
import { AuthRequest } from '../middleware/auth.middleware';
import axios from 'axios';
import { v2 as cloudinary } from 'cloudinary';

const configureCloudinary = async () => {
  const [cloudName, apiKey, apiSecret] = await Promise.all([
    prisma.settings.findUnique({ where: { key: 'cloudinary_cloud_name' } }),
    prisma.settings.findUnique({ where: { key: 'cloudinary_api_key' } }),
    prisma.settings.findUnique({ where: { key: 'cloudinary_api_secret' } }),
  ]);
  cloudinary.config({
    cloud_name: cloudName?.value || process.env.CLOUDINARY_CLOUD_NAME,
    api_key: apiKey?.value || process.env.CLOUDINARY_API_KEY,
    api_secret: apiSecret?.value || process.env.CLOUDINARY_API_SECRET,
  });
};

export const getPaymentSettings = async (_req: any, res: Response): Promise<void> => {
  try {
    const settings = await prisma.settings.findMany({ where: { group: 'payment' } });
    const result: Record<string, string> = {};
    settings.forEach(s => { result[s.key] = s.value; });
    res.json({ success: true, data: result });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const createPayment = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { planId, method } = req.body;
    const plan = await prisma.plan.findUnique({ where: { id: planId } });
    if (!plan || !plan.isActive) {
      res.status(404).json({ success: false, message: 'Plan not found' });
      return;
    }
    const existingActive = await prisma.subscription.findFirst({
      where: { userId: req.user!.id, status: 'ACTIVE', endDate: { gt: new Date() } },
    });
    if (existingActive) {
      res.status(409).json({ success: false, message: 'You already have an active subscription' });
      return;
    }
    const payment = await prisma.payment.create({
      data: { userId: req.user!.id, planId, method, amount: plan.price, status: 'PENDING' },
      include: { plan: true },
    });
    res.status(201).json({ success: true, data: payment });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const uploadProof = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { paymentId } = req.params;
    const payment = await prisma.payment.findFirst({
      where: { id: paymentId, userId: req.user!.id, status: 'PENDING' },
    });
    if (!payment) {
      res.status(404).json({ success: false, message: 'Payment not found' });
      return;
    }
    if (!req.body.imageBase64) {
      res.status(400).json({ success: false, message: 'Image is required' });
      return;
    }
    await configureCloudinary();
    const result = await cloudinary.uploader.upload(req.body.imageBase64, {
      folder: 'game-event/payment-proofs',
      resource_type: 'image',
    });
    const updated = await prisma.payment.update({
      where: { id: paymentId },
      data: { proofImageUrl: result.secure_url },
    });
    res.json({ success: true, data: updated });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const verifyTxid = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { paymentId } = req.params;
    const { txid } = req.body;
    if (!txid) {
      res.status(400).json({ success: false, message: 'TXID is required' });
      return;
    }

    const payment = await prisma.payment.findFirst({
      where: { id: paymentId, userId: req.user!.id, method: 'USDT_BEP20', status: 'PENDING' },
      include: { plan: true },
    });
    if (!payment) {
      res.status(404).json({ success: false, message: 'Payment not found' });
      return;
    }

    const usedTxid = await prisma.usedTxid.findUnique({ where: { txid } });
    if (usedTxid) {
      res.status(409).json({ success: false, message: 'This TXID has already been used' });
      return;
    }

    const apiKeyRow = await prisma.settings.findUnique({ where: { key: 'bscscan_api_key' } });
    const contractRow = await prisma.settings.findUnique({ where: { key: 'usdt_contract_address' } });
    const apiKey = apiKeyRow?.value || process.env.BSCSCAN_API_KEY || '';
    const contract = contractRow?.value || '0x55d398326f99059fF775485246999027B3197955';

    let txValid = false;
    try {
      const response = await axios.get(`https://api.bscscan.com/api`, {
        params: {
          module: 'proxy',
          action: 'eth_getTransactionByHash',
          txhash: txid,
          apikey: apiKey,
        },
      });
      const tx = response.data?.result;
      if (tx && tx.to && tx.to.toLowerCase() === contract.toLowerCase()) {
        txValid = true;
      }
    } catch {
      res.status(502).json({ success: false, message: 'Blockchain verification failed' });
      return;
    }

    if (!txValid) {
      res.status(400).json({ success: false, message: 'Invalid TXID or transaction not found' });
      return;
    }

    await prisma.usedTxid.create({ data: { txid, userId: req.user!.id } });

    const startDate = new Date();
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + payment.plan.durationDays);

    const subscription = await prisma.subscription.create({
      data: { userId: req.user!.id, planId: payment.planId, status: 'ACTIVE', startDate, endDate },
    });

    await prisma.payment.update({
      where: { id: paymentId },
      data: { txid, txidVerified: true, status: 'APPROVED', subscriptionId: subscription.id, reviewedAt: new Date() },
    });

    res.json({ success: true, message: 'Payment verified and subscription activated', data: subscription });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
