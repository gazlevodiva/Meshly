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
}
