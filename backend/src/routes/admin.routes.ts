import { Router } from 'express';
import {
  getDashboard, getUsers, getPendingPayments, getAllPayments,
  approvePayment, rejectPayment, activateSubscription, toggleUser,
  getAdminLogs, getAllSubscriptions,
} from '../controllers/admin.controller';
import { getAllPlans, createPlan, updatePlan, deletePlan } from '../controllers/plan.controller';
import { authenticate, isAdmin } from '../middleware/auth.middleware';

const router = Router();
router.use(authenticate, isAdmin);

router.get('/dashboard', getDashboard);
router.get('/users', getUsers);
router.patch('/users/:userId/toggle', toggleUser);
router.get('/payments/pending', getPendingPayments);
router.get('/payments', getAllPayments);
router.post('/payments/:paymentId/approve', approvePayment);
router.post('/payments/:paymentId/reject', rejectPayment);
router.get('/subscriptions', getAllSubscriptions);
router.post('/subscriptions/activate', activateSubscription);
router.get('/plans', getAllPlans);
router.post('/plans', createPlan);
router.put('/plans/:id', updatePlan);
router.delete('/plans/:id', deletePlan);
router.get('/logs', getAdminLogs);

export default router;
