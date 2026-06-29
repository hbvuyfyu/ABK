export interface AfGame {
  name: string;
  displayName: string;
  package: string;
  devKey: string;
  emoji: string;
  events: AfEvent[];
}

export interface AfEvent {
  eventName: string;
  displayName: string;
  eventType: string;
  isPurchase: boolean;
}

export interface SingularGame {
  name: string;
  displayName: string;
  package: string;
  appKey: string;
  emoji: string;
  events: SingularEvent[];
}

export interface SingularEvent {
  eventName: string;
  displayName: string;
  eventType: string;
}

export interface AdjGame {
  name: string;
  displayName: string;
  appToken: string;
  emoji: string;
  events: AdjEvent[];
}

export interface AdjEvent {
  eventName: string;
  eventToken: string;
  displayName: string;
  levelValue: number;
}

export interface DetectedGame {
  found: true;
  platform: 'af' | 'singular' | 'adj';
  game: AfGame | SingularGame | AdjGame;
}

export interface GameNotFound {
  found: false;
}

export type DetectResult = DetectedGame | GameNotFound;

// ==================== AppsFlyer Games ====================
export const AF_GAMES: AfGame[] = [
  {
    name: 'dice_dream', displayName: 'Dice Dreams', package: 'com.superplaystudios.dicedreams',
    devKey: 'Hn5qYjVAaRNJYDcwF4LaWF', emoji: '🎲',
    events: [
      { eventName: 'af_kingdom_3_restored', displayName: 'Kingdom 3', eventType: 'kingdom', isPurchase: false },
      { eventName: 'af_kingdom_18_restored', displayName: 'Kingdom 18', eventType: 'kingdom', isPurchase: false },
    ],
  },
  {
    name: 'domino_dreams', displayName: 'Domino Dreams', package: 'com.screenshake.dominodreams',
    devKey: 'Hn5qYjVAaRNJYDcwF4LaWF', emoji: '🃏',
    events: [
      { eventName: 'af_area_1_completed', displayName: 'Area 1', eventType: 'area', isPurchase: false },
      { eventName: 'af_area_2_completed', displayName: 'Area 2', eventType: 'area', isPurchase: false },
      { eventName: 'af_area_3_completed', displayName: 'Area 3', eventType: 'area', isPurchase: false },
      { eventName: 'af_area_4_completed', displayName: 'Area 4', eventType: 'area', isPurchase: false },
      { eventName: 'af_area_5_completed', displayName: 'Area 5', eventType: 'area', isPurchase: false },
      { eventName: 'af_level_100_completed', displayName: 'Level 100', eventType: 'level', isPurchase: false },
    ],
  },
  {
    name: 'buzzle_chaos', displayName: 'Buzzle Chaos', package: 'com.global.pnck',
    devKey: 'ZnhUvonKa6qF9xhgt7GcBQ', emoji: '🎲',
    events: [],
  },
  {
    name: 'coin_master', displayName: 'Coin Master', package: 'com.moonactive.coinmaster',
    devKey: 'H3KjoCRVTiVgA5mWSAHtCe', emoji: '🎲',
    events: [
      { eventName: 'village_1_complete', displayName: 'Village 1 Complete', eventType: 'level', isPurchase: false },
    ],
  },
  {
    name: 'royal_match', displayName: 'Royal Match', package: 'com.dreamgames.royalmatch',
    devKey: 'B27HnbGEcbWC2fv79DDhcb', emoji: '👑',
    events: [
      { eventName: 'level_3', displayName: 'Level 3', eventType: 'level', isPurchase: false },
      { eventName: 'area_2', displayName: 'Area 2', eventType: 'area', isPurchase: false },
    ],
  },
  {
    name: 'merge_gardens', displayName: 'Merge Gardens', package: 'com.futureplay.mergematch',
    devKey: 'nr8SibwpFjcKGBQNpDdttd', emoji: '🌺',
    events: [
      { eventName: 'Incent_Player_Level_Up_2', displayName: 'Player Level Up 2', eventType: 'level', isPurchase: false },
      { eventName: 'Incent_IAP_gems2', displayName: 'IAP Gems 2', eventType: 'purchase', isPurchase: true },
    ],
  },
  {
    name: 'highroller_vegas', displayName: 'HIGHROLLER Vegas', package: 'com.lynxgames.hrv',
    devKey: 'sSpBC5SKPKEV8fbZJgw6vM', emoji: '🎲',
    events: [
      { eventName: 'app_level_achieved_5', displayName: 'Level 5', eventType: 'level', isPurchase: false },
    ],
  },
  {
    name: 'rock_n_cash', displayName: 'Rock N Cash Casino', package: 'net.flysher.rockncash',
    devKey: 'W5VWPj5fbCGABtk59TsmJQ', emoji: '💰',
    events: [
      { eventName: 'v3_rnc_level_up_10_S2S', displayName: 'Level Up 10', eventType: 'level', isPurchase: false },
    ],
  },
  {
    name: 'coinchef', displayName: 'COINCHEF', package: 'com.FortuneMine.CuisineMaster',
    devKey: 'im6mgZbZJsHKGVowkkxkGm', emoji: '🍳',
    events: [
      { eventName: 'level2_completed', displayName: 'Level 2 Completed', eventType: 'level', isPurchase: false },
    ],
  },
  {
    name: 'blackjack21', displayName: 'Blackjack 21', package: 'com.kamagames.blackjack',
    devKey: 'YbczyDZZmXbxwpYYyJgqTQ', emoji: '🃏',
    events: [
      { eventName: '2level', displayName: 'Level 2', eventType: 'level', isPurchase: false },
      { eventName: '5levelup', displayName: 'Level 5', eventType: 'level', isPurchase: false },
      { eventName: '30levelup', displayName: 'Level 30', eventType: 'level', isPurchase: false },
    ],
  },
  {
    name: 'sunshine_island', displayName: 'Sunshine Island', package: 'com.newmoonproduction.sunshineisland',
    devKey: 'FtaT5WH9rMJjJkMd4LfBCT', emoji: '🏝️',
    events: [
      { eventName: 'af_level5_achieved', displayName: 'Level 5', eventType: 'level', isPurchase: false },
    ],
  },
  {
    name: 'farmville3', displayName: 'Farmville 3', package: 'com.zynga.FarmVille2CountryEscape',
    devKey: '438VCPmX2ZLYvsDPfGLZXb', emoji: '🌾',
    events: [
      { eventName: 'Player_Level9', displayName: 'Level 9', eventType: 'level', isPurchase: false },
    ],
  },
  {
    name: 'disney_solitaire', displayName: 'Disney Solitaire', package: 'com.superplaystudios.disneysolitairedreams',
    devKey: 'Hn5qYjVAaRNJYDcwF4LaWF', emoji: '🎲',
    events: [
      { eventName: 'af_level_100_completed', displayName: 'Level 100', eventType: 'level', isPurchase: false },
      { eventName: 'af_area_22_completed', displayName: 'Area 22', eventType: 'area', isPurchase: false },
    ],
  },
  {
    name: 'matching_story', displayName: 'Matching Story', package: 'com.joycastle.mergematch',
    devKey: 'v2w2tuNCNaBNXvFJgRGPRW', emoji: '🎲',
    events: [],
  },
  {
    name: 'nations_of_darkness', displayName: 'Nations of Darkness', package: 'com.allstarunion.nod',
    devKey: 'x88hdqNmd8vALRmRMhgY4Q', emoji: '🎲',
    events: [],
  },
  {
    name: 'hero_wars', displayName: 'Hero Wars', package: 'com.nexters.herowars',
    devKey: 'MGPcVAUzD9XqbwAY6q7KMf', emoji: '🎲',
    events: [
      { eventName: 'levelup5', displayName: 'Level Up 5', eventType: 'level', isPurchase: false },
    ],
  },
  {
    name: 'zombie_waves', displayName: 'Zombie Waves', package: 'com.ddup.zombiewaves.zw',
    devKey: 'wiQMRPvGaAYTGBCgM5yN9N', emoji: '🧟',
    events: [
      { eventName: 'af_zw_lv5', displayName: 'Level 5', eventType: 'level', isPurchase: false },
    ],
  },
  {
    name: 'coin_master_board', displayName: 'Coin Master - Board Adventure', package: 'com.moonactive.cmboard',
    devKey: 'H3KjoCRVTiVgA5mWSAHtCe', emoji: '⚔️',
    events: [
      { eventName: 'village_3_complete', displayName: 'Village 3', eventType: 'village', isPurchase: false },
    ],
  },
  {
    name: 'royal_farm', displayName: 'Royal Farm', package: 'com.ugo.play.free.farm.valley',
    devKey: 'ktoVPgaiGM9AZhM5BFycVB', emoji: '🚜',
    events: [
      { eventName: 'af_level_up_10', displayName: 'Level 10', eventType: 'level', isPurchase: false },
    ],
  },
  {
    name: 'idle_zombie_miner', displayName: 'Idle Zombie Miner', package: 'com.zombie.idleminertycoon',
    devKey: 'Ko6tMi9uqZbPBgJsKCuAUd', emoji: '🧟',
    events: [
      { eventName: 'mine_2_reached', displayName: 'Mine 2', eventType: 'mine', isPurchase: false },
    ],
  },
  {
    name: 'travel_town', displayName: 'Travel Town', package: 'io.randomco.travel',
    devKey: 'wizhvjciCuaDbAaR8KpZLn', emoji: '✈️',
    events: [
      { eventName: 'level_completed_1', displayName: 'Level 1', eventType: 'level', isPurchase: false },
    ],
  },
  {
    name: 'goodville', displayName: 'Goodville', package: 'com.goodville.goodgame',
    devKey: 'MqrvZSKujKBZ4byRDHm5a4', emoji: '🏡',
    events: [
      { eventName: 'Start_Exp_1', displayName: 'Start Exp 1', eventType: 'exp', isPurchase: false },
    ],
  },
  {
    name: 'game_of_vampires', displayName: 'Game of Vampires', package: 'com.mechanist.vampire.aos',
    devKey: 'ZCD7jvH8i9zt9ewanppetD', emoji: '🧛',
    events: [
      { eventName: 'power_350w', displayName: 'Power 350w', eventType: 'power', isPurchase: false },
    ],
  },
];

// ==================== Singular Games ====================
export const SINGULAR_GAMES: SingularGame[] = [
  {
    name: 'animals_coins', displayName: 'Animals & Coins', package: 'com.innplaylabs.animalkingdomraid',
    appKey: 'innplay_labs_33d87c9b', emoji: '🦁',
    events: [{ eventName: 'Reach Level 3', displayName: 'Level 3', eventType: 'level' }],
  },
  {
    name: 'time_master', displayName: 'Time Master', package: 'com.firefog.timemaster',
    appKey: 'myappfree_spa_38e49215', emoji: '⏰',
    events: [{ eventName: 'mn_location_1', displayName: 'Location 1', eventType: 'level' }],
  },
  {
    name: 'beast_go', displayName: 'Beast Go', package: 'com.ninthart.board.beastgo',
    appKey: 'myappfree_spa_38e49215', emoji: '🐉',
    events: [{ eventName: 'sng_level_achieved', displayName: 'sng_level_achieved', eventType: 'level' }],
  },
  {
    name: 'coin_fantasy', displayName: 'Coin Fantasy', package: 'com.okvision.coinfantasy',
    appKey: 'myappfree_spa_38e49215', emoji: '💰',
    events: [],
  },
  {
    name: 'dragon_farm', displayName: 'Dragon Farm', package: 'com.dragon.escape.island.adventure',
    appKey: 'myappfree_spa_38e49215', emoji: '🐉',
    events: [{ eventName: 'mn_location_1', displayName: 'Location 1', eventType: 'level' }],
  },
  {
    name: 'box_cat_jam', displayName: 'Box Cat Jam', package: 'com.actionfit.blockcat',
    appKey: 'actionfit_adc62229', emoji: '🐱',
    events: [{ eventName: 'First_attempt_level_', displayName: 'First attempt level', eventType: 'level' }],
  },
  {
    name: 'idle_soap', displayName: 'Idle Soap ASMR', package: 'games.midnite.isa',
    appKey: 'myappfree_spa_38e49215', emoji: '🧼',
    events: [{ eventName: 'soap_unlocked', displayName: 'Soap Unlocked', eventType: 'unlock' }],
  },
  {
    name: 'superheroes_idle', displayName: 'Superheroes Idle RPG', package: 'games.midnite.sid',
    appKey: 'myappfree_spa_38e49215', emoji: '🦸',
    events: [{ eventName: 'mn_cheater_level_achieved', displayName: 'Cheater Level Achieved', eventType: 'level' }],
  },
  {
    name: 'survivor_idle', displayName: 'Survivor Idle Run', package: 'games.midnite.sri',
    appKey: 'myappfree_spa_38e49215', emoji: '🏃',
    events: [{ eventName: 'sng_level_achieved', displayName: 'sng_level_achieved', eventType: 'level' }],
  },
  {
    name: 'pop_slots', displayName: 'POP Slots', package: 'com.playstudios.popslots',
    appKey: 'playstudios_3852f898', emoji: '🎰',
    events: [{ eventName: 'level', displayName: 'Level', eventType: 'level' }],
  },
  {
    name: 'mgm_slots', displayName: 'MGM Slots Live', package: 'com.playstudios.showstar',
    appKey: 'playstudios_3852f898', emoji: '🎰',
    events: [{ eventName: 'level', displayName: 'Level', eventType: 'level' }],
  },
  {
    name: 'myvegas', displayName: 'myVEGAS Slots', package: 'com.playstudios.myvegas',
    appKey: 'playstudios_3852f898', emoji: '🎰',
    events: [{ eventName: 'level', displayName: 'Level', eventType: 'level' }],
  },
  {
    name: 'power_spin', displayName: 'Power Spin Quest', package: 'com.braingames.powerquest',
    appKey: 'brain_games_a7dde873', emoji: '💪',
    events: [{ eventName: 'level_ended_', displayName: 'Level Ended', eventType: 'level' }],
  },
  {
    name: 'sweet_jam', displayName: 'Sweet Jam!', package: 'puzzle.game.sweetjam',
    appKey: 'myappfree_spa_38e49215', emoji: '🍯',
    events: [{ eventName: 'sng_level_achieved', displayName: 'sng_level_achieved', eventType: 'level' }],
  },
  {
    name: 'matching_go', displayName: 'Matching Go!', package: 'com.matchinggo.puzzlegames',
    appKey: 'xinagyi_f4545a5d', emoji: '🔗',
    events: [
      { eventName: 'user_level_complete_', displayName: 'Level Complete', eventType: 'level' },
      { eventName: 'ad_show_', displayName: 'Ad Show', eventType: 'ad' },
    ],
  },
  {
    name: 'screw_out', displayName: 'Screw Out Factory 3D', package: 'com.ntt.screw.out.factory',
    appKey: 'puzzle_studios_4d38bec9', emoji: '🔧',
    events: [],
  },
  {
    name: 'hole_collect', displayName: 'Hole Collect', package: 'com.ntt.hole.collect.objects',
    appKey: 'puzzle_studios_4d38bec9', emoji: '🕳️',
    events: [
      { eventName: 'map_unlocked', displayName: 'Map Unlocked', eventType: 'unlock' },
      { eventName: 'sng_level_achieved', displayName: 'sng_level_achieved', eventType: 'level' },
    ],
  },
  {
    name: 'tetris_block', displayName: 'Tetris Block Party', package: 'com.playstudios.tetrisblockparty',
    appKey: 'playstudios_3852f898', emoji: '🧩',
    events: [{ eventName: 'level_', displayName: 'Level', eventType: 'level' }],
  },
  {
    name: 'word_madness', displayName: 'Word Madness', package: 'com.word.madness',
    appKey: 'brain_games_a7dde873', emoji: '📖',
    events: [{ eventName: '_levels_completed', displayName: 'Levels Completed', eventType: 'level' }],
  },
  {
    name: 'word_wise', displayName: 'Word Wise', package: 'com.playx.wordwise.crossword',
    appKey: 'myappfree_spa_38e49215', emoji: '📖',
    events: [{ eventName: 'mn_level_', displayName: 'Level', eventType: 'level' }],
  },
  {
    name: 'eatventure', displayName: 'Eatventure', package: 'com.hwqgrhhjfd.idlefastfood',
    appKey: 'lessmore_edff53fc', emoji: '🍔',
    events: [
      { eventName: 'restaurant_unlocked', displayName: 'Restaurant Unlocked', eventType: 'unlock' },
      { eventName: 'lm_restaurant_completion', displayName: 'Restaurant Completion', eventType: 'complete' },
    ],
  },
  {
    name: 'myappfree', displayName: 'MyAppFree', package: 'myappfreesrl.com.myappfree',
    appKey: 'loyaltydigital_10c54e02', emoji: '📱',
    events: [
      { eventName: 'cashout_s2s', displayName: 'First Cashout', eventType: 'cashout' },
      { eventName: '3_cashout_s2s', displayName: '3 Cashouts', eventType: 'cashout' },
      { eventName: '7_cashout_s2s', displayName: '7 Cashouts', eventType: 'cashout' },
    ],
  },
  {
    name: 'supermarketaffairs', displayName: 'Supermarket Affairs', package: 'com.potatoplay.supermarketaffairs',
    appKey: 'potatoplay_52168b49', emoji: '🎮',
    events: [
      { eventName: 'sma_player_level_3', displayName: 'Level 3', eventType: 'level' },
      { eventName: 'sma_buy_sma000002', displayName: '5$ Purchase', eventType: 'purchase' },
      { eventName: 'sma_buy_sma000003', displayName: '10$ Purchase', eventType: 'purchase' },
    ],
  },
  {
    name: 'mergerestaurant', displayName: 'Merge Restaurant', package: 'com.potatoplay.mergerestaurant',
    appKey: 'potatoplay_52168b49', emoji: '🍳',
    events: [{ eventName: 'lv5_playerLevelUp', displayName: 'Level 5', eventType: 'level' }],
  },
];

// ==================== Adjust Games ====================
export const ADJ_GAMES: AdjGame[] = [
  {
    name: 'get_color', displayName: 'Get Color', appToken: '367kicwptj5s', emoji: '🎨',
    events: [
      { eventName: 'level_15', eventToken: '8t8nb3', displayName: 'Level 15', levelValue: 15 },
      { eventName: 'level_30', eventToken: 'uwq9v8', displayName: 'Level 30', levelValue: 30 },
      { eventName: 'level_50', eventToken: 'fdlgyk', displayName: 'Level 50', levelValue: 50 },
      { eventName: 'level_75', eventToken: 'dwhyjz', displayName: 'Level 75', levelValue: 75 },
      { eventName: 'level_100', eventToken: 'txq8if', displayName: 'Level 100', levelValue: 100 },
      { eventName: 'level_150', eventToken: 'lwhvaj', displayName: 'Level 150', levelValue: 150 },
      { eventName: 'level_200', eventToken: 'stpy1k', displayName: 'Level 200', levelValue: 200 },
    ],
  },
  {
    name: 'merge_blocks', displayName: '2048 X2 Merge Blocks', appToken: '367kicwptj5s', emoji: '🔲',
    events: [
      { eventName: 'event_callback_yd6777', eventToken: 'yd6777', displayName: 'Reach Step 5', levelValue: 5 },
      { eventName: 'event_callback_8mpa1x', eventToken: '8mpa1x', displayName: 'Step 10', levelValue: 10 },
      { eventName: 'event_callback_j9tstz', eventToken: 'j9tstz', displayName: 'Step 25', levelValue: 25 },
      { eventName: 'event_callback_g3mipt', eventToken: 'g3mipt', displayName: 'Step 50', levelValue: 50 },
      { eventName: 'event_callback_v197np', eventToken: 'v197np', displayName: 'Step 100', levelValue: 100 },
    ],
  },
  {
    name: 'bingo_aloha', displayName: 'Bingo Aloha', appToken: '367kicwptj5s', emoji: '🍍',
    events: [
      { eventName: 'event_callback_tr4vq2', eventToken: 'tr4vq2', displayName: 'Level 20', levelValue: 20 },
      { eventName: 'event_callback_f82iiq', eventToken: 'f82iiq', displayName: 'Level 30', levelValue: 30 },
      { eventName: 'event_callback_3yza9s', eventToken: '3yza9s', displayName: 'Level 50', levelValue: 50 },
      { eventName: 'event_callback_w5tltt', eventToken: 'w5tltt', displayName: 'Level 80', levelValue: 80 },
    ],
  },
  {
    name: 'battle_night', displayName: 'Battle Night', appToken: '367kicwptj5s', emoji: '⚔️',
    events: [
      { eventName: 'event_callback_wdu1px', eventToken: 'wdu1px', displayName: 'Collect 2 Purple Heroes', levelValue: 2 },
      { eventName: 'event_callback_f6z6gr', eventToken: 'f6z6gr', displayName: 'Complete Chapter 6', levelValue: 6 },
      { eventName: 'event_callback_jb6urh', eventToken: 'jb6urh', displayName: '1 Orange Hero', levelValue: 1 },
    ],
  },
  {
    name: 'blast_friends', displayName: 'Blast Friends', appToken: '367kicwptj5s', emoji: '💥',
    events: [
      { eventName: 'event_callback_v5zsay', eventToken: 'v5zsay', displayName: 'Level 20', levelValue: 20 },
      { eventName: 'event_callback_qco1yc', eventToken: 'qco1yc', displayName: 'Level 50', levelValue: 50 },
      { eventName: 'event_callback_nmbpbj', eventToken: 'nmbpbj', displayName: 'Level 100', levelValue: 100 },
    ],
  },
  {
    name: 'block_blitz', displayName: 'Block Blitz', appToken: '367kicwptj5s', emoji: '🧱',
    events: [
      { eventName: 'event_callback_z9gmw7', eventToken: 'z9gmw7', displayName: 'Level 5', levelValue: 5 },
      { eventName: 'event_callback_erj7x3', eventToken: 'erj7x3', displayName: 'Level 10', levelValue: 10 },
      { eventName: 'event_callback_bqkl2c', eventToken: 'bqkl2c', displayName: 'Level 50', levelValue: 50 },
      { eventName: 'event_callback_nm5hzf', eventToken: 'nm5hzf', displayName: 'Level 100', levelValue: 100 },
    ],
  },
];

// ==================== Package Lookup Maps ====================
export const AF_BY_PACKAGE = new Map<string, AfGame>(
  AF_GAMES.map((g) => [g.package, g])
);

export const SINGULAR_BY_PACKAGE = new Map<string, SingularGame>(
  SINGULAR_GAMES.map((g) => [g.package, g])
);

export function detectGameByPackage(pkg: string): DetectResult {
  const afGame = AF_BY_PACKAGE.get(pkg);
  if (afGame) return { found: true, platform: 'af', game: afGame };

  const singularGame = SINGULAR_BY_PACKAGE.get(pkg);
  if (singularGame) return { found: true, platform: 'singular', game: singularGame };

  return { found: false };
}
