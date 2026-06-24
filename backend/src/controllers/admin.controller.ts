import { Response } from 'express';
import prisma from '../utils/prisma';
import { AuthRequest } from '../middleware/auth.middleware';

export const getDashboard = async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const [totalUsers, activeSubscriptions, pendingPayments, totalRevenue] = await Promise.all([
      prisma.user.count({ where: { role: 'USER' } }),
      prisma.subscription.count({ where: { status: 'ACTIVE', endDate: { gt: new Date() } } }),
      prisma.payment.count({ where: { status: 'PENDING' } }),
      prisma.payment.aggregate({ where: { status: 'APPROVED' }, _sum: { amount: true } }),
    ]);
    res.json({
      success: true,
      data: {
        totalUsers,
        activeSubscriptions,
        pendingPayments,
        totalRevenue: totalRevenue._sum.amount || 0,
      },
    });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const getUsers = async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const users = await prisma.user.findMany({
      where: { role: 'USER' },
      select: {
        id: true, email: true, name: true, isActive: true, createdAt: true,
        subscriptions: {
          where: { status: 'ACTIVE', endDate: { gt: new Date() } },
          include: { plan: true },
          take: 1,
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ success: true, data: users });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const getAllSubscriptions = async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const subscriptions = await prisma.subscription.findMany({
      include: {
        user: { select: { id: true, email: true, name: true } },
        plan: true,
      },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ success: true, data: subscriptions });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const getPendingPayments = async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const payments = await prisma.payment.findMany({
      where: { status: 'PENDING' },
      include: { user: { select: { id: true, email: true, name: true } }, plan: true },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ success: true, data: payments });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const getAllPayments = async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const payments = await prisma.payment.findMany({
      include: { user: { select: { id: true, email: true, name: true } }, plan: true },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ success: true, data: payments });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const approvePayment = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { paymentId } = req.params;
    const payment = await prisma.payment.findUnique({ where: { id: paymentId }, include: { plan: true } });
    if (!payment || payment.status !== 'PENDING') {
      res.status(404).json({ success: false, message: 'Payment not found or already processed' });
      return;
    }
    const startDate = new Date();
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + payment.plan.durationDays);
    const subscription = await prisma.subscription.create({
      data: { userId: payment.userId, planId: payment.planId, status: 'ACTIVE', startDate, endDate },
    });
    await prisma.payment.update({
      where: { id: paymentId },
      data: { status: 'APPROVED', subscriptionId: subscription.id, reviewedBy: req.user!.id, reviewedAt: new Date() },
    });
    await prisma.adminLog.create({
      data: { adminId: req.user!.id, targetId: payment.userId, action: 'PAYMENT_APPROVED', details: `Payment ${paymentId} approved` },
    });
    res.json({ success: true, message: 'Payment approved and subscription activated' });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const rejectPayment = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { paymentId } = req.params;
    const { adminNotes } = req.body;
    const payment = await prisma.payment.findUnique({ where: { id: paymentId } });
    if (!payment || payment.status !== 'PENDING') {
      res.status(404).json({ success: false, message: 'Payment not found or already processed' });
      return;
    }
    await prisma.payment.update({
      where: { id: paymentId },
      data: { status: 'REJECTED', adminNotes, reviewedBy: req.user!.id, reviewedAt: new Date() },
    });
    await prisma.adminLog.create({
      data: { adminId: req.user!.id, targetId: payment.userId, action: 'PAYMENT_REJECTED', details: `Payment ${paymentId} rejected` },
    });
    res.json({ success: true, message: 'Payment rejected' });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const activateSubscription = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { userId, planId } = req.body;
    const plan = await prisma.plan.findUnique({ where: { id: planId } });
    if (!plan) {
      res.status(404).json({ success: false, message: 'Plan not found' });
      return;
    }
    await prisma.subscription.updateMany({
      where: { userId, status: 'ACTIVE' },
      data: { status: 'CANCELLED' },
    });
    const startDate = new Date();
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + plan.durationDays);
    const subscription = await prisma.subscription.create({
      data: { userId, planId, status: 'ACTIVE', startDate, endDate },
    });
    await prisma.adminLog.create({
      data: { adminId: req.user!.id, targetId: userId, action: 'SUBSCRIPTION_ACTIVATED', details: `Plan ${planId} activated manually` },
    });
    res.json({ success: true, data: subscription });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const toggleUser = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      res.status(404).json({ success: false, message: 'User not found' });
      return;
    }
    const updated = await prisma.user.update({ where: { id: userId }, data: { isActive: !user.isActive } });
    res.json({ success: true, data: { isActive: updated.isActive } });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const getAdminLogs = async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const logs = await prisma.adminLog.findMany({
      include: {
        admin: { select: { email: true, name: true } },
        target: { select: { email: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    res.json({ success: true, data: logs });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
