import { Request, Response } from 'express';
import axios from 'axios';
import { detectGameByPackage, AfGame, SingularGame, AdjGame } from '../data/games_data';

// ==================== Detect Game ====================
export async function detectGame(req: Request, res: Response): Promise<void> {
  const pkg = (req.query.package as string || '').trim();
  if (!pkg) {
    res.status(400).json({ success: false, message: 'package query parameter is required' });
    return;
  }

  const result = detectGameByPackage(pkg);
  if (!result.found) {
    res.json({ success: true, found: false, message: 'Game not in supported list' });
    return;
  }

  const { platform, game } = result;
  let requiredFields: string[] = [];
  let firstEvent: any = null;

  if (platform === 'af') {
    const afGame = game as AfGame;
    requiredFields = ['gaid', 'af_uid'];
    firstEvent = afGame.events.find(e => !e.isPurchase) || afGame.events[0] || null;
    res.json({
      success: true,
      found: true,
      platform,
      game: {
        name: afGame.name,
        displayName: afGame.displayName,
        package: afGame.package,
        devKey: afGame.devKey,
        emoji: afGame.emoji,
        events: afGame.events,
      },
      requiredFields,
      firstEvent,
    });
  } else if (platform === 'singular') {
    const sg = game as SingularGame;
    requiredFields = ['gaid', 'uid'];
    firstEvent = sg.events[0] || null;
    res.json({
      success: true,
      found: true,
      platform,
      game: {
        name: sg.name,
        displayName: sg.displayName,
        package: sg.package,
        appKey: sg.appKey,
        emoji: sg.emoji,
        events: sg.events,
      },
      requiredFields,
      firstEvent,
    });
  } else {
    res.json({ success: true, found: false, message: 'ADJ detection requires manual game selection' });
  }
}

// ==================== Send AppsFlyer Event ====================
async function sendAF(
  pkg: string, devKey: string, gaid: string, afUid: string,
  eventName: string, revenue?: number
): Promise<{ status: number; body: string }> {
  const url = `https://api2.appsflyer.com/inappevent/${pkg}`;
  const now = Date.now();
  const DEVICE_MODEL = 'SM-S911B';
  const SDK_VERSION = '6.15.0';
  const APP_VERSION = '2.3.0';

  const eventValue: any = {};
  if (revenue) {
    eventValue.af_content_id = `combo_${Math.floor(Math.random() * 50) + 1}`;
    eventValue.af_content_type = 'purchase';
    eventValue.af_currency = 'USD';
    eventValue.af_price = String(revenue);
  } else {
    const levelNum = eventName.replace(/[^0-9]/g, '');
    if (levelNum) {
      eventValue.af_level = levelNum;
      eventValue.af_score = String(Math.floor(Math.random() * 49000) + 1000);
      eventValue.af_duration = String(Math.floor(Math.random() * 270) + 30);
    }
  }

  const payload: any = {
    appsflyer_id: afUid,
    advertising_id: gaid,
    eventName: eventName,
    eventTime: now,
    eventValue,
    device_model: DEVICE_MODEL,
    os_version: 'Android 14',
    sdk_version: SDK_VERSION,
    app_version_name: APP_VERSION,
    network: 'WiFi',
    language: 'en-US',
    timezone: 'Asia/Riyadh',
  };

  if (revenue) {
    payload.eventRevenue = String(revenue);
    payload.eventCurrency = 'USD';
  }

  const headers = {
    Authentication: devKey,
    'User-Agent': `AppsFlyer-Android-SDK/${SDK_VERSION} (Linux; Android 14; ${DEVICE_MODEL})`,
    'Content-Type': 'application/json',
    Accept: '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    Connection: 'keep-alive',
  };

  try {
    const r = await axios.post(url, payload, { headers, timeout: 30000 });
    return { status: r.status, body: typeof r.data === 'string' ? r.data : JSON.stringify(r.data) };
  } catch (err: any) {
    const status = err?.response?.status ?? 500;
    const body = err?.response?.data ? JSON.stringify(err.response.data) : String(err.message);
    return { status, body };
  }
}

// ==================== Send Adjust Event ====================
async function sendADJ(
  appToken: string, eventToken: string, gpsAdid: string
): Promise<{ status: number; body: string }> {
  const params = {
    app_token: appToken,
    event_token: eventToken,
    gps_adid: gpsAdid,
    s2s: '1',
    created_at: String(Math.floor(Date.now() / 1000)),
  };

  const headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    Accept: 'application/json',
  };

  try {
    const r = await axios.get('https://s2s.adjust.com/event', { params, headers, timeout: 30000 });
    return { status: r.status, body: typeof r.data === 'string' ? r.data : JSON.stringify(r.data) };
  } catch (err: any) {
    const status = err?.response?.status ?? 500;
    const body = err?.response?.data ? JSON.stringify(err.response.data) : String(err.message);
    return { status, body };
  }
}

// ==================== Send Singular Event ====================
async function sendSingular(
  eventName: string, aifa: string, uid: string,
  pkg: string, appKey: string, level?: number
): Promise<{ status: number; body: string }> {
  const payload: any = {
    a: appKey,
    p: pkg,
    i: aifa,
    e: eventName,
    t: Date.now(),
  };
  if (uid) payload.cu = uid;
  if (level) payload.lvl = level;

  const headers = {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  };

  try {
    const r = await axios.post('https://s2s.singular.net/api/v1/evt', payload, { headers, timeout: 30000 });
    return { status: r.status, body: typeof r.data === 'string' ? r.data : JSON.stringify(r.data) };
  } catch (err: any) {
    const status = err?.response?.status ?? 500;
    const body = err?.response?.data ? JSON.stringify(err.response.data) : String(err.message);
    return { status, body };
  }
}

// ==================== Send Event Endpoint ====================
export async function sendEvent(req: Request, res: Response): Promise<void> {
  const { platform, package: pkg, gaid, afUid, appKey, appToken,
          eventName, eventToken, devKey, level, revenue } = req.body;

  if (!platform) {
    res.status(400).json({ success: false, message: 'platform is required' });
    return;
  }

  try {
    let result: { status: number; body: string };

    if (platform === 'af') {
      if (!pkg || !devKey || !gaid || !afUid || !eventName) {
        res.status(400).json({ success: false, message: 'AF requires: package, devKey, gaid, afUid, eventName' });
        return;
      }
      result = await sendAF(pkg, devKey, gaid, afUid, eventName, revenue);
    } else if (platform === 'adj') {
      if (!appToken || !eventToken || !gaid) {
        res.status(400).json({ success: false, message: 'ADJ requires: appToken, eventToken, gaid' });
        return;
      }
      result = await sendADJ(appToken, eventToken, gaid);
    } else if (platform === 'singular') {
      if (!pkg || !appKey || !gaid || !eventName) {
        res.status(400).json({ success: false, message: 'Singular requires: package, appKey, gaid, eventName' });
        return;
      }
      result = await sendSingular(eventName, gaid, afUid || '', pkg, appKey, level);
    } else {
      res.status(400).json({ success: false, message: 'Unknown platform. Use: af, adj, singular' });
      return;
    }

    const ok = result.status >= 200 && result.status < 300;
    res.json({
      success: ok,
      statusCode: result.status,
      response: result.body,
      platform,
      eventName: eventName || eventToken,
    });
  } catch (err: any) {
    res.status(500).json({ success: false, message: String(err.message) });
  }
}

// ==================== List All Games ====================
export function listGames(_req: Request, res: Response): void {
  const { AF_GAMES, SINGULAR_GAMES, ADJ_GAMES } = require('../data/games_data');
  res.json({
    success: true,
    af: AF_GAMES.map((g: AfGame) => ({ name: g.name, displayName: g.displayName, package: g.package, emoji: g.emoji })),
    singular: SINGULAR_GAMES.map((g: SingularGame) => ({ name: g.name, displayName: g.displayName, package: g.package, emoji: g.emoji })),
    adj: ADJ_GAMES.map((g: AdjGame) => ({ name: g.name, displayName: g.displayName, emoji: g.emoji })),
  });
}
