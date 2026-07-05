// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Отмена';

  @override
  String get add => 'Добавить';

  @override
  String get navChats => 'Чаты';

  @override
  String get navContacts => 'Контакты';

  @override
  String get navSettings => 'Настройки';

  @override
  String get searchHint => 'Поиск...';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get appTagline => 'Люди, которым вы доверяете';

  @override
  String get bluetoothPermissionNeeded => 'Нужен доступ к Bluetooth';

  @override
  String get connectionErrorTitle => 'Ошибка подключения';

  @override
  String get checkConnection => 'Проверьте подключение';

  @override
  String get helpTipPoweredOn => 'Девайс включён и заряжен';

  @override
  String get helpTipBluetoothOn => 'Bluetooth включён на телефоне';

  @override
  String get helpTipKeepClose => 'Держите девайс ближе к телефону';

  @override
  String get helpTipRestart => 'Перезагрузите девайс';

  @override
  String get searchAgain => 'Искать снова';

  @override
  String get connectToDeviceTitle => 'Подключитесь к устройству';

  @override
  String get connectToDeviceHint =>
      'Включите Bluetooth и держите устройство рядом';

  @override
  String get stopScan => 'Остановить';

  @override
  String get findDevice => 'Найти устройство';

  @override
  String get scanningNearby => 'Поиск устройств рядом...';

  @override
  String get availableDevices => 'Доступные устройства';

  @override
  String get searchingMeshtastic => 'Ищем Meshtastic-устройства...';

  @override
  String get deviceNotListed => 'Устройство не в списке?';

  @override
  String connectingTo(String name) {
    return 'Подключение к $name...';
  }

  @override
  String get otherDevice => 'Другое устройство';

  @override
  String get onboardingTitle1 => 'Общайтесь без интернета\nи сотовой связи';

  @override
  String get onboardingText1 =>
      'Сообщения идут напрямую между устройствами Meshtastic по радио. Никаких тарифов и вышек — связь работает даже там, где нет сети.';

  @override
  String get onboardingTitle2 => 'Нужен Meshtastic-девайс';

  @override
  String get onboardingText2 =>
      'Включите девайс и держите его рядом с телефоном. Приложение само подключится к нему по Bluetooth.';

  @override
  String get onboardingTitle3 => 'Люди, которым\nвы доверяете';

  @override
  String get onboardingText3 =>
      'Обменяйтесь QR-кодами с теми, кому доверяете, и создайте общий канал для своих.';

  @override
  String get onboardingSkip => 'Пропустить';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingStart => 'Начать';

  @override
  String get addContact => 'Добавить контакт';

  @override
  String get createChannel => 'Создать канал';

  @override
  String get myContact => 'Мой контакт';

  @override
  String get statusConnected => 'Подключено';

  @override
  String get statusNoConnection => 'Нет подключения';

  @override
  String get emptyChatsTitle => 'Пока нет чатов';

  @override
  String get emptyChatsSubtitle => 'Добавьте контакт или создайте канал';

  @override
  String get contactsTitle => 'Контакты';

  @override
  String get noContactsHint => 'Нет контактов. Добавьте через +';

  @override
  String get chatFallbackTitle => 'Чат';

  @override
  String strangerNodeId(String nodeId) {
    return 'Незнакомец · $nodeId';
  }

  @override
  String get online => 'В сети';

  @override
  String lastSeen(String time) {
    return 'Был(а) в сети $time';
  }

  @override
  String get editContactTooltip => 'Изменить контакт';

  @override
  String get aboutChannelTooltip => 'О канале';

  @override
  String get backTooltip => 'Назад';

  @override
  String get messageHint => 'Сообщение...';

  @override
  String get notDeliveredTitle => 'Не доставлено';

  @override
  String get resendQuestion => 'Отправить это сообщение ещё раз?';

  @override
  String get retrySend => 'Повторить отправку';

  @override
  String get writeFirstMessage => 'Напишите первое сообщение!';

  @override
  String get nameLabel => 'Имя';

  @override
  String get mePrefix => 'Я';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsSectionProfile => 'Профиль';

  @override
  String get myProfileQrTitle => 'Мой профиль и QR-код';

  @override
  String get shareYourContactSubtitle => 'Поделитесь своим контактом';

  @override
  String get settingsSectionDevice => 'Устройство';

  @override
  String connectedToName(String name) {
    return 'Подключено: $name';
  }

  @override
  String get tapToDisconnect => 'Нажмите чтобы отключиться';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationSettingsTile => 'Настройки уведомлений';

  @override
  String get notificationsEnabled => 'Включены';

  @override
  String get notificationsDisabled => 'Выключены';

  @override
  String get settingsSectionBlocked => 'Заблокированные';

  @override
  String get blockedNodesTile => 'Заблокированные ноды';

  @override
  String get noBlockedNodes => 'Нет заблокированных нод';

  @override
  String blockedCount(int count) {
    return 'Заблокировано: $count';
  }

  @override
  String get settingsSectionAppearance => 'Внешний вид';

  @override
  String get languageTile => 'Язык';

  @override
  String get languageSystem => 'Системный';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeTile => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get settingsSectionAbout => 'О приложении';

  @override
  String versionOpenSource(String version) {
    return 'v$version · Open source';
  }

  @override
  String get allNotifications => 'Все уведомления';

  @override
  String get masterSwitchSubtitle => 'Главный переключатель';

  @override
  String get sourcesSection => 'Источники';

  @override
  String get directMessages => 'Личные сообщения';

  @override
  String get channelsLabel => 'Каналы';

  @override
  String get mutedSection => 'Замьюченные';

  @override
  String get unmuteButton => 'Включить';

  @override
  String get unblockButton => 'Разблокировать';

  @override
  String get saveButton => 'Сохранить';

  @override
  String get shareContact => 'Поделиться контактом';

  @override
  String get copyLinkButton => 'Скопировать ссылку';

  @override
  String get linkCopied => 'Ссылка скопирована';

  @override
  String get blockNodeQuestion => 'Заблокировать?';

  @override
  String get blockNodeWarning =>
      'Нода больше не будет отображаться в мессенджере. Сообщения от неё будут игнорироваться.';

  @override
  String get blockAction => 'Заблокировать';

  @override
  String get deleteContactQuestion => 'Удалить контакт?';

  @override
  String deleteContactWarning(String name) {
    return 'Контакт «$name» будет удалён.';
  }

  @override
  String get deleteAction => 'Удалить';

  @override
  String get deleteContactAction => 'Удалить контакт';

  @override
  String get additionalInfoTitle => 'Дополнительно';

  @override
  String get additionalInfoSubtitle =>
      'Node ID, время последнего соединения и другая информация';

  @override
  String get addedLabel => 'Добавлен';

  @override
  String get lastHeardLabel => 'Последний раз в сети';

  @override
  String get offline => 'Не в сети';

  @override
  String addedOn(String date) {
    return 'Добавлен $date';
  }

  @override
  String get editSheetTitle => 'Редактировать';

  @override
  String get iconLabel => 'Иконка';

  @override
  String get emojiInputHint => 'Введите любой эмодзи...';

  @override
  String get doneButton => 'Готово';

  @override
  String slotN(int slot) {
    return 'Слот $slot';
  }

  @override
  String get shareQrToInvite =>
      'Поделитесь QR-кодом чтобы пригласить участника';

  @override
  String get encryptionLabel => 'Шифрование';

  @override
  String get encryptionValue => 'AES-256, уникальный ключ';

  @override
  String get pskLabel => 'Ключ (PSK)';

  @override
  String get deleteChannelAction => 'Удалить канал';

  @override
  String get deleteChannelQuestion => 'Удалить канал?';

  @override
  String deleteChannelWarning(String name) {
    return 'Канал \"$name\" будет удалён локально. Другие участники продолжат его видеть.';
  }

  @override
  String get addTitle => 'Добавить';

  @override
  String get unrecognizedQr => 'Нераспознанный QR-код';

  @override
  String get tabScanQr => 'Скан QR';

  @override
  String get tabManual => 'Вручную';

  @override
  String cameraError(String error) {
    return 'Ошибка камеры: $error';
  }

  @override
  String get pointCameraAtQr => 'Наведите камеру на QR-код контакта или канала';

  @override
  String get addContactQuestion => 'Добавить контакт?';

  @override
  String get addChannelQuestion => 'Добавить канал?';

  @override
  String get emojiLabel => 'Эмодзи';

  @override
  String get newChannelTitle => 'Новый канал';

  @override
  String get allSlotsBusy => 'Все слоты заняты (максимум 7 каналов)';

  @override
  String get channelNameLabel => 'Название канала';

  @override
  String get channelNameHint => 'Горная группа';

  @override
  String get channelIconLabel => 'Иконка канала';

  @override
  String get channelCreateInfo =>
      'Канал создастся с уникальным ключом шифрования. Поделитесь QR-кодом канала с теми кого хотите добавить.';

  @override
  String get chooseIconTitle => 'Выберите иконку';

  @override
  String get defaultMyName => 'Я';

  @override
  String get askScanQr =>
      'Попросите собеседника отсканировать этот QR\nили поделитесь ссылкой';

  @override
  String get chooseEmojiTitle => 'Выберите эмодзи';

  @override
  String get yourNameHint => 'Ваше имя';

  @override
  String get dateToday => 'Сегодня';

  @override
  String get dateYesterday => 'Вчера';

  @override
  String get relativeToday => 'сегодня';

  @override
  String get dateJustNow => 'только что';

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минуты назад',
      many: '$count минут назад',
      few: '$count минуты назад',
      one: '$count минуту назад',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count часа назад',
      many: '$count часов назад',
      few: '$count часа назад',
      one: '$count час назад',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня назад',
      many: '$count дней назад',
      few: '$count дня назад',
      one: '$count день назад',
    );
    return '$_temp0';
  }
}
