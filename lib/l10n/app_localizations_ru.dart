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
  String get bluetoothOffTitle => 'Bluetooth выключен';

  @override
  String get bluetoothOffHint =>
      'Включите Bluetooth, чтобы найти устройство поблизости';

  @override
  String get enableBluetooth => 'Включить Bluetooth';

  @override
  String get openSettings => 'Открыть настройки';

  @override
  String get connectionErrorTitle => 'Ошибка подключения';

  @override
  String get notMeshtasticDevice =>
      'Похоже, это не Meshtastic-устройство. Выберите другое из списка.';

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
  String get showAllDevices => 'Показать все устройства';

  @override
  String get showMeshtasticOnly => 'Только Meshtastic';

  @override
  String connectingTo(String name) {
    return 'Подключение к $name...';
  }

  @override
  String get otherDevice => 'Другое устройство';

  @override
  String get pairingHintTitle => 'Запрос на сопряжение';

  @override
  String get pairingHintBody =>
      'Введите код с экрана устройства. Если окно не появилось — проверьте шторку уведомлений.';

  @override
  String get radioRegionTitle => 'Регион радио';

  @override
  String get radioRegionNotSet => 'Не задан';

  @override
  String get radioNotConfiguredTitle => 'Устройство ещё не настроено';

  @override
  String get radioNotConfiguredBody =>
      'Пока не выбран регион, устройство не выходит в эфир — сообщения никуда не уйдут. Регион задаёт частоту, на которой разрешено вещать там, где вы находитесь.';

  @override
  String get radioRegionChoose => 'Выбрать регион';

  @override
  String get radioRegionHint =>
      'Выберите регион той страны, где вы находитесь. Работа на чужой частоте нарушает местные правила радиосвязи.';

  @override
  String get radioRegionCommon => 'Частые';

  @override
  String get radioRegionAll => 'Все регионы';

  @override
  String get radioRegionApplying =>
      'Применяем настройку. Устройство перезагрузится и подключится само.';

  @override
  String get radioRegionFailed =>
      'Не удалось изменить регион. Проверьте подключение к устройству.';

  @override
  String get radioRegionReading => 'Читаем настройки устройства…';

  @override
  String radioRegionUnknownCode(int code) {
    return 'Неизвестный код ($code)';
  }

  @override
  String radioRegionSuggestBody(String code) {
    return 'Похоже, вам подходит $code. Настроить устройство?';
  }

  @override
  String get radioRegionSuggestConfirm => 'Настроить';

  @override
  String get radioRegionSuggestOther => 'Выбрать другой регион';

  @override
  String get radioRegionChangeWarning =>
      'Связь со всеми, у кого устройство осталось на прежнем регионе, прервётся.';

  @override
  String get radioRegionIncompatibleSection => 'Другой диапазон';

  @override
  String get radioRegionIncompatibleWarning =>
      'Эти регионы работают на другой частоте, чем плата уже настроена. Железо устройства может не поддерживать такой диапазон — связь пропадёт.';

  @override
  String get settingsAdvancedTitle => 'Дополнительно';

  @override
  String get settingsAdvancedSubtitle => 'Подключение и регион радио';

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
      'Обменяйтесь QR-кодами с теми, кому доверяете, и создайте общую беседу для своих.';

  @override
  String get onboardingSkip => 'Пропустить';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingStart => 'Начать';

  @override
  String get onboardingNameTitle => 'Как вас будут видеть';

  @override
  String get onboardingNameText =>
      'Ваше имя увидят те, кому вы напишете, — вместо номера устройства.';

  @override
  String get addContact => 'Добавить контакт';

  @override
  String get createChannel => 'Создать беседу';

  @override
  String get myContact => 'Мой контакт';

  @override
  String get statusConnected => 'Подключено';

  @override
  String get statusNoConnection => 'Нет подключения';

  @override
  String get statusReconnecting => 'Переподключение…';

  @override
  String get emptyChatsTitle => 'Пока нет чатов';

  @override
  String get emptyChatsSubtitle => 'Добавьте контакт или создайте беседу';

  @override
  String get contactsTitle => 'Контакты';

  @override
  String get noContactsHint => 'Нет контактов. Добавьте через +';

  @override
  String get chatFallbackTitle => 'Чат';

  @override
  String get online => 'В сети';

  @override
  String lastSeen(String time) {
    return 'Был(а) в сети $time';
  }

  @override
  String get editContactTooltip => 'Изменить контакт';

  @override
  String get aboutChannelTooltip => 'О беседе';

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
  String systemEventJoined(String name) {
    return '$name присоединяется к беседе';
  }

  @override
  String systemEventLeft(String name) {
    return '$name покидает беседу';
  }

  @override
  String get nameLabel => 'Имя';

  @override
  String get rescanForSecureChat =>
      'Сначала отсканируйте QR-код этого человека — иначе сообщение не дойдёт';

  @override
  String get undecryptableBubble => '🔒 Не удалось прочитать';

  @override
  String get undecryptablePreview => '🔒 Не удалось прочитать';

  @override
  String get secureChatBrokenPreview => '🔒 Нужно обменяться QR-кодами';

  @override
  String get secureChatBrokenTitle => 'Нужно обменяться QR-кодами';

  @override
  String get secureChatBrokenBody =>
      'Покажите друг другу QR-коды — это полминуты. Так бывает, когда у человека новый телефон.';

  @override
  String get sendAnywayButton => 'Всё равно писать в этот чат';

  @override
  String get keyExchangeStepScan => 'Вы сканируете код собеседника';

  @override
  String get keyExchangeStepShow => 'Собеседник сканирует ваш код';

  @override
  String get keyExchangeAskPeer =>
      'Попросите собеседника открыть «Мой контакт» в приложении';

  @override
  String get keyExchangeHint =>
      'Галочка появится сама, когда собеседник отсканирует ваш код';

  @override
  String get connectDeviceFirst => 'Сначала подключитесь к устройству';

  @override
  String get secureChatRestored => 'Готово — теперь вы читаете друг друга';

  @override
  String get scanQrButton => 'Отсканировать QR-код';

  @override
  String get showMyQrButton => 'Показать мой код';

  @override
  String get mePrefix => 'Я';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsSectionProfile => 'Профиль';

  @override
  String get myProfileQrTitle => 'Имя, эмодзи и QR-код';

  @override
  String get shareYourContactSubtitle =>
      'Как вас видят другие — и как поделиться контактом';

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
  String get blockedNodesTile => 'Заблокированные устройства';

  @override
  String get noBlockedNodes => 'Нет заблокированных устройств';

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
  String get channelsLabel => 'Беседы';

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
      'Устройство больше не будет отображаться в мессенджере. Сообщения от него будут игнорироваться.';

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
      'ID устройства, время последнего соединения и другая информация';

  @override
  String get deviceIdLabel => 'ID устройства';

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
  String get shareQrToInvite =>
      'Поделитесь QR-кодом чтобы пригласить участника';

  @override
  String get encryptionLabel => 'Шифрование';

  @override
  String get encryptionValue =>
      'Сквозное шифрование, свой ключ у каждой беседы';

  @override
  String get pskLabel => 'Ключ шифрования';

  @override
  String get channelMembersInfo =>
      'Списка участников нет: в беседе состоит любой, у кого есть её ключ, — приложение не может это отследить.';

  @override
  String get leaveChannelConfirmAction => 'Выйти';

  @override
  String get deleteChannelAction => 'Выйти из беседы';

  @override
  String get deleteChannelQuestion => 'Выйти из беседы?';

  @override
  String deleteChannelWarning(String name) {
    return 'Беседа \"$name\" исчезнет с этого устройства вместе с перепиской. Остальные участники увидят, что вы вышли.';
  }

  @override
  String get channelEventsTitle => 'Входы и выходы';

  @override
  String get channelEventsNote =>
      'Это не список участников: здесь только входы и выходы, которые заметило это устройство, — часть объявлений не доходит. Записи присылают сами участники, и они не проверяются.';

  @override
  String get channelEventsEmpty =>
      'Пока не замечено ни одного входа или выхода';

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
  String get pointCameraAtQr => 'Наведите камеру на QR-код контакта или беседы';

  @override
  String get addContactQuestion => 'Добавить контакт?';

  @override
  String get addChannelQuestion => 'Добавить беседу?';

  @override
  String get emojiLabel => 'Эмодзи';

  @override
  String get newChannelTitle => 'Новая беседа';

  @override
  String get channelNameLabel => 'Название беседы';

  @override
  String get channelNameHint => 'Горная группа';

  @override
  String get channelIconLabel => 'Иконка беседы';

  @override
  String get channelCreateInfo =>
      'Беседа создастся с уникальным ключом шифрования. Поделитесь QR-кодом с теми, кого хотите добавить. Учтите: убрать кого-то из беседы нельзя — ключ общий для всех и не меняется.';

  @override
  String get chooseIconTitle => 'Выберите иконку';

  @override
  String get askScanQr =>
      'Попросите собеседника отсканировать этот QR\nили поделитесь ссылкой';

  @override
  String get chooseEmojiTitle => 'Выберите эмодзи';

  @override
  String get yourNameHint => 'Ваше имя';

  @override
  String get myCardNoNameTitle => 'Имя ещё не задано';

  @override
  String get myCardNoNameMessage =>
      'Укажите имя выше, чтобы поделиться своим контактом: собеседник, отсканировавший QR-код, сохранит вас под этим именем.';

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
