import { Router } from 'express';
import { detectGame, sendEvent, listGames } from '../controllers/games.controller';

const router = Router();

router.get('/detect', detectGame);
router.post('/send-event', sendEvent);
router.get('/list', listGames);

export default router;
