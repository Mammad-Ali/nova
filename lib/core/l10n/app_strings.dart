import 'package:flutter/widgets.dart';

/// Поддерживаемые языки приложения.
enum AppLocale {
  en,
  az,
  ru;

  Locale get locale => switch (this) {
        AppLocale.en => const Locale('en'),
        AppLocale.az => const Locale('az'),
        AppLocale.ru => const Locale('ru'),
      };

  /// Название языка на самом этом языке (для списка выбора).
  String get nativeName => switch (this) {
        AppLocale.en => 'English',
        AppLocale.az => 'Azərbaycan',
        AppLocale.ru => 'Русский',
      };

  static AppLocale fromCode(String? code) => switch (code) {
        'en' => AppLocale.en,
        'az' => AppLocale.az,
        'ru' => AppLocale.ru,
        _ => AppLocale.ru,
      };
}

/// Все тексты интерфейса. Один неизменяемый объект на язык.
class AppStrings {
  const AppStrings({
    required this.tabSpeed,
    required this.tabMonitor,
    required this.language,
    required this.speedtestSubtitle,
    required this.phaseIdle,
    required this.phasePing,
    required this.phaseDownload,
    required this.phaseUpload,
    required this.phaseDone,
    required this.phaseError,
    required this.ping,
    required this.jitter,
    required this.download,
    required this.upload,
    required this.startTest,
    required this.stopTest,
    required this.errorGeneric,
    required this.historyTitle,
    required this.historyClear,
    required this.historyEmpty,
    required this.comfortTitle,
    required this.actBrowsing,
    required this.actHdVideo,
    required this.act4k,
    required this.actGaming,
    required this.actVideoCalls,
    required this.actStreaming,
    required this.actBigDownloads,
    required this.levelPoor,
    required this.levelOk,
    required this.levelGood,
    required this.levelGreat,
    required this.monitorSubtitle,
    required this.peak,
    required this.session,
    required this.last2min,
    required this.waitingFirst,
    required this.sourceUnavailable,
    required this.resetSession,
    required this.usagePastHour,
    required this.usageToday,
    required this.usageNote,
    required this.providerLabel,
    required this.providerDetecting,
    required this.overall,
    required this.gradeBlazing,
    required this.gradeFast,
    required this.gradeGood,
    required this.gradeModerate,
    required this.gradeSlow,
    required this.personalBest,
    required this.newRecord,
    required this.vsLast,
    required this.copyResult,
    required this.copied,
    required this.serverLabel,
    required this.bloatTitle,
    required this.bloatIdle,
    required this.bloatLoaded,
    required this.bloatIncrease,
    required this.bloatExcellent,
    required this.bloatGood,
    required this.bloatFair,
    required this.bloatPoor,
    required this.bloatHint,
    required this.stabilityTitle,
    required this.stabilityLoss,
    required this.stabilityAvg,
    required this.stabilityMax,
    required this.stabilityOutage,
    required this.pause,
    required this.resume,
    required this.usageMonth,
    required this.usageForecast,
    required this.usageForecastHint,
    required this.usageByDay,
    required this.servicesTitle,
    required this.servicesHint,
    required this.servicesRefresh,
    required this.servicesUnreachable,
    required this.throttleTitle,
    required this.throttleHint,
    required this.throttleRun,
    required this.throttleNeutral,
    required this.throttleVideo,
    required this.throttleNone,
    required this.throttleSuspected,
    required this.throttleLikely,
    required this.throttleLocalCache,
    required this.settings,
    required this.alertsEnable,
    required this.alertMinSpeed,
    required this.alertDailyLimit,
    required this.notSet,
    required this.alertSlowTitle,
    required this.alertSlowBody,
    required this.alertLimitTitle,
    required this.alertLimitBody,
    required this.saveImage,
    required this.exportCsv,
    required this.savedTo,
  });

  // Навигация / общее
  final String tabSpeed;
  final String tabMonitor;
  final String language;

  // Speedtest
  final String speedtestSubtitle;
  final String phaseIdle;
  final String phasePing;
  final String phaseDownload;
  final String phaseUpload;
  final String phaseDone;
  final String phaseError;
  final String ping;
  final String jitter;
  final String download;
  final String upload;
  final String startTest;
  final String stopTest;
  final String errorGeneric;

  // История
  final String historyTitle;
  final String historyClear;
  final String historyEmpty;

  // Шкала комфорта
  final String comfortTitle;
  final String actBrowsing;
  final String actHdVideo;
  final String act4k;
  final String actGaming;
  final String actVideoCalls;
  final String actStreaming;
  final String actBigDownloads;
  final String levelPoor;
  final String levelOk;
  final String levelGood;
  final String levelGreat;

  // Монитор
  final String monitorSubtitle;
  final String peak;
  final String session;
  final String last2min;
  final String waitingFirst;
  final String sourceUnavailable;
  final String resetSession;
  final String usagePastHour;
  final String usageToday;
  final String usageNote;

  // Провайдер, оценка, рекорд, сравнение, копирование
  final String providerLabel;
  final String providerDetecting;
  final String overall;
  final String gradeBlazing;
  final String gradeFast;
  final String gradeGood;
  final String gradeModerate;
  final String gradeSlow;
  final String personalBest;
  final String newRecord;
  final String vsLast;
  final String copyResult;
  final String copied;

  // Сервер, bufferbloat, стабильность
  final String serverLabel;
  final String bloatTitle;
  final String bloatIdle;
  final String bloatLoaded;
  final String bloatIncrease;
  final String bloatExcellent;
  final String bloatGood;
  final String bloatFair;
  final String bloatPoor;
  final String bloatHint;
  final String stabilityTitle;
  final String stabilityLoss;
  final String stabilityAvg;
  final String stabilityMax;
  final String stabilityOutage;
  final String pause;
  final String resume;
  final String usageMonth;
  final String usageForecast;
  final String usageForecastHint;
  final String usageByDay;
  final String servicesTitle;
  final String servicesHint;
  final String servicesRefresh;
  final String servicesUnreachable;
  final String throttleTitle;
  final String throttleHint;
  final String throttleRun;
  final String throttleNeutral;
  final String throttleVideo;
  final String throttleNone;
  final String throttleSuspected;
  final String throttleLikely;
  final String throttleLocalCache;

  // Настройки, уведомления, экспорт
  final String settings;
  final String alertsEnable;
  final String alertMinSpeed;
  final String alertDailyLimit;
  final String notSet;

  /// Шаблоны с плейсхолдерами {0}/{1} — подставляются через [fill].
  final String alertSlowTitle;
  final String alertSlowBody;
  final String alertLimitTitle;
  final String alertLimitBody;

  final String saveImage;
  final String exportCsv;
  final String savedTo;

  /// Подставляет значения в шаблон: `fill('{0} из {1}', ['2', '5'])`.
  static String fill(String template, List<String> args) {
    var out = template;
    for (var i = 0; i < args.length; i++) {
      out = out.replaceAll('{$i}', args[i]);
    }
    return out;
  }

  static AppStrings of(AppLocale locale) => switch (locale) {
        AppLocale.en => _en,
        AppLocale.az => _az,
        AppLocale.ru => _ru,
      };
}

const _en = AppStrings(
  tabSpeed: 'Speed',
  tabMonitor: 'Monitor',
  language: 'Language',
  speedtestSubtitle: 'Maximum connection speed',
  phaseIdle: 'Ready to test',
  phasePing: 'Measuring ping…',
  phaseDownload: 'Downloading…',
  phaseUpload: 'Uploading…',
  phaseDone: 'Done',
  phaseError: 'Error',
  ping: 'Ping',
  jitter: 'Jitter',
  download: 'Download',
  upload: 'Upload',
  startTest: 'Start test',
  stopTest: 'Stop',
  errorGeneric: 'Test failed',
  historyTitle: 'Test history',
  historyClear: 'Clear',
  historyEmpty: 'No completed tests yet',
  comfortTitle: 'What this speed is good for',
  actBrowsing: 'Web & social',
  actHdVideo: 'HD video (1080p)',
  act4k: '4K video',
  actGaming: 'Online gaming',
  actVideoCalls: 'Video calls',
  actStreaming: 'Live streaming',
  actBigDownloads: 'Large downloads',
  levelPoor: 'Poor',
  levelOk: 'OK',
  levelGood: 'Good',
  levelGreat: 'Excellent',
  monitorSubtitle: 'System-wide · every second',
  peak: 'PEAK',
  session: 'SESSION',
  last2min: 'Last 2 minutes',
  waitingFirst: 'Waiting for the first sample…',
  sourceUnavailable: 'Traffic source unavailable',
  resetSession: 'Reset session',
  usagePastHour: 'Past hour',
  usageToday: 'Today',
  usageNote: 'Counted while the app is open',
  providerLabel: 'Provider',
  providerDetecting: 'Detecting…',
  overall: 'Connection grade',
  gradeBlazing: 'Blazing',
  gradeFast: 'Fast',
  gradeGood: 'Good',
  gradeModerate: 'Moderate',
  gradeSlow: 'Slow',
  personalBest: 'Personal best',
  newRecord: 'New record!',
  vsLast: 'vs last',
  copyResult: 'Copy result',
  copied: 'Copied to clipboard',
  serverLabel: 'Server',
  bloatTitle: 'Latency under load',
  bloatIdle: 'Idle',
  bloatLoaded: 'Under load',
  bloatIncrease: 'Increase',
  bloatExcellent: 'Excellent',
  bloatGood: 'Good',
  bloatFair: 'Noticeable',
  bloatPoor: 'Severe',
  bloatHint: 'How much lag appears when the connection is busy — '
      'this is what breaks games and calls.',
  stabilityTitle: 'Connection stability',
  stabilityLoss: 'Packet loss',
  stabilityAvg: 'Average',
  stabilityMax: 'Peak',
  stabilityOutage: 'Connection lost',
  pause: 'Pause',
  resume: 'Resume',
  usageMonth: 'This month',
  usageForecast: 'Forecast',
  usageForecastHint: 'Projected total by the end of the month at the current pace',
  usageByDay: 'By day',
  servicesTitle: 'Latency to services',
  servicesHint: 'Shows where exactly the delay is, not just "the internet is slow"',
  servicesRefresh: 'Measure again',
  servicesUnreachable: 'no reply',
  throttleTitle: 'Video throttling check',
  throttleHint: 'Compares speed to a neutral CDN and to Netflix servers',
  throttleRun: 'Check',
  throttleNeutral: 'Regular CDN',
  throttleVideo: 'Video CDN',
  throttleNone: 'No throttling detected',
  throttleSuspected: 'Video is noticeably slower',
  throttleLikely: 'Video is heavily slowed down',
  throttleLocalCache: 'Provider hosts a local video cache',
  settings: 'Settings',
  alertsEnable: 'System notifications',
  alertMinSpeed: 'Warn below (Mbps)',
  alertDailyLimit: 'Daily traffic limit (GB)',
  notSet: 'off',
  alertSlowTitle: 'Speed below your threshold',
  alertSlowBody: 'Test measured {0} Mbps, below your {1} Mbps threshold.',
  alertLimitTitle: 'Daily traffic limit reached',
  alertLimitBody: 'Used {0} GB of your {1} GB limit today.',
  saveImage: 'Save as image',
  exportCsv: 'Export CSV',
  savedTo: 'Saved',
);

const _az = AppStrings(
  tabSpeed: 'Sürət',
  tabMonitor: 'Monitor',
  language: 'Dil',
  speedtestSubtitle: 'Maksimum bağlantı sürəti',
  phaseIdle: 'Testə hazır',
  phasePing: 'Ping ölçülür…',
  phaseDownload: 'Yüklənir…',
  phaseUpload: 'Göndərilir…',
  phaseDone: 'Hazırdır',
  phaseError: 'Xəta',
  ping: 'Ping',
  jitter: 'Jitter',
  download: 'Yükləmə',
  upload: 'Göndərmə',
  startTest: 'Testə başla',
  stopTest: 'Dayandır',
  errorGeneric: 'Test alınmadı',
  historyTitle: 'Test tarixçəsi',
  historyClear: 'Təmizlə',
  historyEmpty: 'Hələ tamamlanmış test yoxdur',
  comfortTitle: 'Bu sürət nəyə uyğundur',
  actBrowsing: 'Veb və sosial',
  actHdVideo: 'HD video (1080p)',
  act4k: '4K video',
  actGaming: 'Onlayn oyunlar',
  actVideoCalls: 'Video zənglər',
  actStreaming: 'Canlı yayım',
  actBigDownloads: 'Böyük yükləmələr',
  levelPoor: 'Zəif',
  levelOk: 'Normal',
  levelGood: 'Yaxşı',
  levelGreat: 'Əla',
  monitorSubtitle: 'Bütün sistem · hər saniyə',
  peak: 'PİK',
  session: 'SESSİYA',
  last2min: 'Son 2 dəqiqə',
  waitingFirst: 'İlk ölçü gözlənilir…',
  sourceUnavailable: 'Trafik mənbəyi əlçatan deyil',
  resetSession: 'Sessiyanı sıfırla',
  usagePastHour: 'Son saat',
  usageToday: 'Bu gün',
  usageNote: 'Yalnız tətbiq açıq olanda sayılır',
  providerLabel: 'Provayder',
  providerDetecting: 'Təyin edilir…',
  overall: 'Bağlantı qiyməti',
  gradeBlazing: 'İldırım kimi',
  gradeFast: 'Sürətli',
  gradeGood: 'Yaxşı',
  gradeModerate: 'Orta',
  gradeSlow: 'Yavaş',
  personalBest: 'Şəxsi rekord',
  newRecord: 'Yeni rekord!',
  vsLast: 'əvvəlki ilə',
  copyResult: 'Nəticəni kopyala',
  copied: 'Panoya kopyalandı',
  serverLabel: 'Server',
  bloatTitle: 'Yük altında gecikmə',
  bloatIdle: 'Sakit',
  bloatLoaded: 'Yük altında',
  bloatIncrease: 'Artım',
  bloatExcellent: 'Əla',
  bloatGood: 'Yaxşı',
  bloatFair: 'Nəzərəçarpan',
  bloatPoor: 'Ciddi',
  bloatHint: 'Kanal məşğul olanda nə qədər gecikmə yaranır — '
      'oyunları və zəngləri məhz bu pozur.',
  stabilityTitle: 'Bağlantı sabitliyi',
  stabilityLoss: 'Paket itkisi',
  stabilityAvg: 'Orta',
  stabilityMax: 'Maksimum',
  stabilityOutage: 'Bağlantı itdi',
  pause: 'Dayandır',
  resume: 'Davam et',
  usageMonth: 'Bu ay',
  usageForecast: 'Proqnoz',
  usageForecastHint: 'İndiki templə ay sonuna gözlənilən ümumi həcm',
  usageByDay: 'Günlər üzrə',
  servicesTitle: 'Servislərə gecikmə',
  servicesHint: 'Gecikmənin harada olduğunu göstərir, sadəcə «internet yavaşdır» deyil',
  servicesRefresh: 'Yenidən ölç',
  servicesUnreachable: 'cavab yoxdur',
  throttleTitle: 'Video məhdudlaşdırma yoxlaması',
  throttleHint: 'Adi CDN və Netflix serverlərinə sürəti müqayisə edir',
  throttleRun: 'Yoxla',
  throttleNeutral: 'Adi CDN',
  throttleVideo: 'Video CDN',
  throttleNone: 'Məhdudlaşdırma aşkarlanmadı',
  throttleSuspected: 'Video nəzərəçarpacaq dərəcədə yavaşdır',
  throttleLikely: 'Video ciddi şəkildə yavaşladılır',
  throttleLocalCache: 'Provayderdə lokal video keş var',
  settings: 'Tənzimləmələr',
  alertsEnable: 'Sistem bildirişləri',
  alertMinSpeed: 'Xəbərdarlıq həddi (Mbps)',
  alertDailyLimit: 'Günlük trafik limiti (GB)',
  notSet: 'söndürülüb',
  alertSlowTitle: 'Sürət həddən aşağıdır',
  alertSlowBody: 'Test {0} Mbps göstərdi — bu, {1} Mbps həddindən aşağıdır.',
  alertLimitTitle: 'Günlük limit doldu',
  alertLimitBody: 'Bu gün {1} GB limitin {0} GB-ı istifadə olunub.',
  saveImage: 'Şəkil kimi saxla',
  exportCsv: 'CSV ixrac et',
  savedTo: 'Saxlanıldı',
);

const _ru = AppStrings(
  tabSpeed: 'Скорость',
  tabMonitor: 'Монитор',
  language: 'Язык',
  speedtestSubtitle: 'Максимальная скорость соединения',
  phaseIdle: 'Готов к тесту',
  phasePing: 'Измеряем пинг…',
  phaseDownload: 'Загрузка…',
  phaseUpload: 'Отдача…',
  phaseDone: 'Готово',
  phaseError: 'Ошибка',
  ping: 'Пинг',
  jitter: 'Джиттер',
  download: 'Загрузка',
  upload: 'Отдача',
  startTest: 'Начать тест',
  stopTest: 'Остановить',
  errorGeneric: 'Не удалось выполнить тест',
  historyTitle: 'История тестов',
  historyClear: 'Очистить',
  historyEmpty: 'Пока нет завершённых тестов',
  comfortTitle: 'Для чего хватит этой скорости',
  actBrowsing: 'Сайты и соцсети',
  actHdVideo: 'HD-видео (1080p)',
  act4k: '4K-видео',
  actGaming: 'Онлайн-игры',
  actVideoCalls: 'Видеозвонки',
  actStreaming: 'Стриминг (вещание)',
  actBigDownloads: 'Большие загрузки',
  levelPoor: 'Плохо',
  levelOk: 'Нормально',
  levelGood: 'Хорошо',
  levelGreat: 'Отлично',
  monitorSubtitle: 'Системный трафик · каждую секунду',
  peak: 'ПИК',
  session: 'СЕССИЯ',
  last2min: 'Последние 2 минуты',
  waitingFirst: 'Ждём первый замер…',
  sourceUnavailable: 'Источник трафика недоступен',
  resetSession: 'Сбросить сессию',
  usagePastHour: 'За час',
  usageToday: 'Сегодня',
  usageNote: 'Учитывается, пока приложение открыто',
  providerLabel: 'Провайдер',
  providerDetecting: 'Определяем…',
  overall: 'Оценка соединения',
  gradeBlazing: 'Молниеносно',
  gradeFast: 'Быстро',
  gradeGood: 'Хорошо',
  gradeModerate: 'Средне',
  gradeSlow: 'Медленно',
  personalBest: 'Личный рекорд',
  newRecord: 'Новый рекорд!',
  vsLast: 'к прошлому',
  copyResult: 'Скопировать результат',
  copied: 'Скопировано в буфер',
  serverLabel: 'Сервер',
  bloatTitle: 'Пинг под нагрузкой',
  bloatIdle: 'В покое',
  bloatLoaded: 'Под нагрузкой',
  bloatIncrease: 'Прирост',
  bloatExcellent: 'Отлично',
  bloatGood: 'Хорошо',
  bloatFair: 'Заметно',
  bloatPoor: 'Сильно',
  bloatHint: 'Насколько растут задержки, когда канал занят — '
      'именно это портит игры и звонки.',
  stabilityTitle: 'Стабильность связи',
  stabilityLoss: 'Потери пакетов',
  stabilityAvg: 'Средний',
  stabilityMax: 'Пик',
  stabilityOutage: 'Связь потеряна',
  pause: 'Пауза',
  resume: 'Возобновить',
  usageMonth: 'За месяц',
  usageForecast: 'Прогноз',
  usageForecastHint: 'Сколько выйдет к концу месяца при текущем темпе',
  usageByDay: 'По дням',
  servicesTitle: 'Пинг до сервисов',
  servicesHint: 'Показывает, где именно задержка, а не просто «интернет тормозит»',
  servicesRefresh: 'Замерить заново',
  servicesUnreachable: 'нет ответа',
  throttleTitle: 'Проверка на троттлинг видео',
  throttleHint: 'Сравнивает скорость до обычного CDN и до серверов Netflix',
  throttleRun: 'Проверить',
  throttleNeutral: 'Обычный CDN',
  throttleVideo: 'Видео-CDN',
  throttleNone: 'Троттлинга не обнаружено',
  throttleSuspected: 'Видео заметно медленнее',
  throttleLikely: 'Видео сильно замедляется',
  throttleLocalCache: 'У провайдера локальный кэш видео',
  settings: 'Настройки',
  alertsEnable: 'Системные уведомления',
  alertMinSpeed: 'Предупреждать ниже (Мбит/с)',
  alertDailyLimit: 'Дневной лимит трафика (ГБ)',
  notSet: 'выключено',
  alertSlowTitle: 'Скорость ниже порога',
  alertSlowBody: 'Тест показал {0} Мбит/с — это ниже вашего порога {1} Мбит/с.',
  alertLimitTitle: 'Достигнут дневной лимит',
  alertLimitBody: 'Сегодня израсходовано {0} ГБ из {1} ГБ.',
  saveImage: 'Сохранить картинкой',
  exportCsv: 'Экспорт CSV',
  savedTo: 'Сохранено',
);
