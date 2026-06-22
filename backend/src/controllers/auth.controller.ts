import { Request, Response } from 'express';
  import bcrypt from 'bcryptjs';
  import jwt, { SignOptions } from 'jsonwebtoken';
  import prisma from '../utils/prisma';

  function makeToken(payload: object): string {
    const secret = process.env.JWT_SECRET || 'secret';
    const opts: SignOptions = { expiresIn: (process.env.JWT_EXPIRES_IN || '7d') as SignOptions['expiresIn'] };
    return jwt.sign(payload, secret, opts);
  }

  export const register = async (req: Request, res: Response): Promise<void> => {
    try {
      const { email, password, name } = req.body;
      if (!email || !password) {
        res.status(400).json({ success: false, message: 'Email and password are required' });
        return;
      }
      const existing = await prisma.user.findUnique({ where: { email } });
      if (existing) {
        res.status(409).json({ success: false, message: 'Email already registered' });
        return;
      }
      const hashed = await bcrypt.hash(password, 12);
      const user = await prisma.user.create({
        data: { email, password: hashed, name },
        select: { id: true, email: true, name: true, role: true, createdAt: true },
      });
      const token = makeToken({ id: user.id, email: user.email, role: user.role });
      res.status(201).json({ success: true, data: { user, token } });
    } catch {
      res.status(500).json({ success: false, message: 'Server error' });
    }
  };

  export const login = async (req: Request, res: Response): Promise<void> => {
    try {
      const { email, password } = req.body;
      if (!email || !password) {
        res.status(400).json({ success: false, message: 'Email and password are required' });
        return;
      }
      const user = await prisma.user.findUnique({ where: { email } });
      if (!user || !user.isActive) {
        res.status(401).json({ success: false, message: 'Invalid credentials' });
        return;
      }
      const valid = await bcrypt.compare(password, user.password);
      if (!valid) {
        res.status(401).json({ success: false, message: 'Invalid credentials' });
        return;
      }
      const token = makeToken({ id: user.id, email: user.email, role: user.role });
      res.json({
        success: true,
        data: {
          user: { id: user.id, email: user.email, name: user.name, role: user.role },
          token,
        },
      });
    } catch {
      res.status(500).json({ success: false, message: 'Server error' });
    }
  };

  export const getMe = async (req: any, res: Response): Promise<void> => {
    try {
      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
        select: { id: true, email: true, name: true, role: true, createdAt: true },
      });
      res.json({ success: true, data: user });
    } catch (error) {
      console.error('Register error:', error);
      res.status(500).json({ success: false, message: 'Server error', error: String(error) });
    }
  };
  
