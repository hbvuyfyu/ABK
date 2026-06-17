import { Request, Response } from 'express';
import prisma from '../utils/prisma';

export const getPlans = async (_req: Request, res: Response): Promise<void> => {
  try {
    const plans = await prisma.plan.findMany({ where: { isActive: true }, orderBy: { price: 'asc' } });
    res.json({ success: true, data: plans });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const getAllPlans = async (_req: Request, res: Response): Promise<void> => {
  try {
    const plans = await prisma.plan.findMany({ orderBy: { price: 'asc' } });
    res.json({ success: true, data: plans });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

export const updatePlan = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { name, nameAr, durationDays, dailyOperations, price, isActive } = req.body;
    const plan = await prisma.plan.update({
      where: { id },
      data: { name, nameAr, durationDays, dailyOperations, price, isActive },
    });
    res.json({ success: true, data: plan });
  } catch {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
