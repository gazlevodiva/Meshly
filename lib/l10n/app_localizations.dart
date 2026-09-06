import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @ok.
  ///
  /// In ru, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// Short affirmative button: add a contact (stranger banner, add-contact dialog)
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get add;

  /// No description provided for @navChats.
  ///
  /// In ru, this message translates to:
  /// **'Чаты'**
  String get navChats;

  /// No description provided for @navContacts.
  ///
  /// In ru, this message translates to:
  /// **'Контакты'**
  String get navContacts;

  /// No description provided for @navSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get navSettings;

  /// Placeholder in the inline search field on the Chats/Contacts tabs
  ///
  /// In ru, this message translates to:
  /// **'Поиск...'**
  String get searchHint;

  /// Empty state when a search query matches nothing
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get nothingFound;

  /// Tagline under the Meshly logo on the scan screen
  ///
  /// In ru, this message translates to:
  /// **'Люди, которым вы доверяете'**
  String get appTagline;

  /// No description provided for @bluetoothPermissionNeeded.
  ///
  /// In ru, this message translates to:
  /// **'Нужен доступ к Bluetooth'**
  String get bluetoothPermissionNeeded;

  /// Heading on the scan screen when the phone's Bluetooth adapter is off
  ///
  /// In ru, this message translates to:
  /// **'Bluetooth выключен'**
  String get bluetoothOffTitle;

  /// No description provided for @bluetoothOffHint.
  ///
  /// In ru, this message translates to:
  /// **'Включите Bluetooth, чтобы найти устройство поблизости'**
  String get bluetoothOffHint;

  /// Button (Android) that opens the system dialog to turn Bluetooth on
  ///
  /// In ru, this message translates to:
  /// **'Включить Bluetooth'**
  String get enableBluetooth;

  /// Button (iOS) that opens system settings so the user can enable Bluetooth
  ///
  /// In ru, this message translates to:
  /// **'Открыть настройки'**
  String get openSettings;

  /// No description provided for @connectionErrorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка подключения'**
  String get connectionErrorTitle;

  /// Connection error dialog body shown when the tapped BLE device turns out not to be a Meshtastic radio (no Meshtastic service/characteristics)
  ///
  /// In ru, this message translates to:
  /// **'Похоже, это не Meshtastic-устройство. Выберите другое из списка.'**
  String get notMeshtasticDevice;

  /// Both the help bottom-sheet title and the footer link that opens it
  ///
  /// In ru, this message translates to:
  /// **'Проверьте подключение'**
  String get checkConnection;

  /// No description provided for @helpTipPoweredOn.
  ///
  /// In ru, this message translates to:
  /// **'Девайс включён и заряжен'**
  String get helpTipPoweredOn;

  /// No description provided for @helpTipBluetoothOn.
  ///
  /// In ru, this message translates to:
  /// **'Bluetooth включён на телефоне'**
  String get helpTipBluetoothOn;

  /// No description provided for @helpTipKeepClose.
  ///
  /// In ru, this message translates to:
  /// **'Держите девайс ближе к телефону'**
  String get helpTipKeepClose;

  /// No description provided for @helpTipRestart.
  ///
  /// In ru, this message translates to:
  /// **'Перезагрузите девайс'**
  String get helpTipRestart;

  /// No description provided for @searchAgain.
  ///
  /// In ru, this message translates to:
  /// **'Искать снова'**
  String get searchAgain;

  /// No description provided for @connectToDeviceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подключитесь к устройству'**
  String get connectToDeviceTitle;

  /// No description provided for @connectToDeviceHint.
  ///
  /// In ru, this message translates to:
  /// **'Включите Bluetooth и держите устройство рядом'**
  String get connectToDeviceHint;

  /// Button that stops an active BLE scan
  ///
  /// In ru, this message translates to:
  /// **'Остановить'**
  String get stopScan;

  /// No description provided for @findDevice.
  ///
  /// In ru, this message translates to:
  /// **'Найти устройство'**
  String get findDevice;

  /// No description provided for @scanningNearby.
  ///
  /// In ru, this message translates to:
  /// **'Поиск устройств рядом...'**
  String get scanningNearby;

  /// No description provided for @availableDevices.
  ///
  /// In ru, this message translates to:
  /// **'Доступные устройства'**
  String get availableDevices;

  /// No description provided for @searchingMeshtastic.
  ///
  /// In ru, this message translates to:
  /// **'Ищем Meshtastic-устройства...'**
  String get searchingMeshtastic;

  /// No description provided for @deviceNotListed.
  ///
  /// In ru, this message translates to:
  /// **'Устройство не в списке?'**
  String get deviceNotListed;

  /// Scan screen footer toggle: drop the Meshtastic filter and list every BLE device (escape hatch for uncommon/renamed boards)
  ///
  /// In ru, this message translates to:
  /// **'Показать все устройства'**
  String get showAllDevices;

  /// Scan screen footer toggle: re-enable the Meshtastic-only device filter
  ///
  /// In ru, this message translates to:
  /// **'Только Meshtastic'**
  String get showMeshtasticOnly;

  /// Shown while connecting to a BLE device
  ///
  /// In ru, this message translates to:
  /// **'Подключение к {name}...'**
  String connectingTo(String name);

  /// Button to cancel auto-connect and pick another device
  ///
  /// In ru, this message translates to:
  /// **'Другое устройство'**
  String get otherDevice;

  /// Heading of the pairing hint card shown while connecting for the first time
  ///
  /// In ru, this message translates to:
  /// **'Запрос на сопряжение'**
  String get pairingHintTitle;

  /// Explains that the BLE pairing code is shown on the device screen and the system prompt may arrive as a notification
  ///
  /// In ru, this message translates to:
  /// **'Введите код с экрана устройства. Если окно не появилось — проверьте шторку уведомлений.'**
  String get pairingHintBody;

  /// Title of the radio-region setting and of the region picker screen
  ///
  /// In ru, this message translates to:
  /// **'Регион радио'**
  String get radioRegionTitle;

  /// Value shown next to the region setting while the device region is UNSET
  ///
  /// In ru, this message translates to:
  /// **'Не задан'**
  String get radioRegionNotSet;

  /// Heading of the card shown after connecting to a radio whose LoRa region is unset
  ///
  /// In ru, this message translates to:
  /// **'Устройство ещё не настроено'**
  String get radioNotConfiguredTitle;

  /// Explains why an unconfigured radio silently fails to send anything
  ///
  /// In ru, this message translates to:
  /// **'Пока не выбран регион, устройство не выходит в эфир — сообщения никуда не уйдут. Регион задаёт частоту, на которой разрешено вещать там, где вы находитесь.'**
  String get radioNotConfiguredBody;

  /// Button that opens the region picker
  ///
  /// In ru, this message translates to:
  /// **'Выбрать регион'**
  String get radioRegionChoose;

  /// Legal warning at the top of the region picker; the region is never guessed for the user
  ///
  /// In ru, this message translates to:
  /// **'Выберите регион той страны, где вы находитесь. Работа на чужой частоте нарушает местные правила радиосвязи.'**
  String get radioRegionHint;

  /// Section heading above the short list of the most common LoRa regions
  ///
  /// In ru, this message translates to:
  /// **'Частые'**
  String get radioRegionCommon;

  /// Section heading above the full list of LoRa region codes
  ///
  /// In ru, this message translates to:
  /// **'Все регионы'**
  String get radioRegionAll;

  /// Shown after the region was sent; the radio reboots and reconnects on its own
  ///
  /// In ru, this message translates to:
  /// **'Применяем настройку. Устройство перезагрузится и подключится само.'**
  String get radioRegionApplying;

  /// Shown when the region write could not be sent
  ///
  /// In ru, this message translates to:
  /// **'Не удалось изменить регион. Проверьте подключение к устройству.'**
  String get radioRegionFailed;

  /// Placeholder while the device config has not arrived yet and the region is unknown
  ///
  /// In ru, this message translates to:
  /// **'Читаем настройки устройства…'**
  String get radioRegionReading;

  /// Region value reported by a newer firmware that this app does not know yet
  ///
  /// In ru, this message translates to:
  /// **'Неизвестный код ({code})'**
  String radioRegionUnknownCode(int code);

  /// One-tap setup: shown when the phone's platform locale suggests a region for the device (no country name — see project notes on why)
  ///
  /// In ru, this message translates to:
  /// **'Похоже, вам подходит {code}. Настроить устройство?'**
  String radioRegionSuggestBody(String code);

  /// Primary button that applies the suggested region
  ///
  /// In ru, this message translates to:
  /// **'Настроить'**
  String get radioRegionSuggestConfirm;

  /// Secondary link below the one-tap suggestion, opens the full region list
  ///
  /// In ru, this message translates to:
  /// **'Выбрать другой регион'**
  String get radioRegionSuggestOther;

  /// Shown in the confirmation sheet when the device already has a region set and the user is changing it
  ///
  /// In ru, this message translates to:
  /// **'Связь со всеми, у кого устройство осталось на прежнем регионе, прервётся.'**
  String get radioRegionChangeWarning;

  /// Heading above regions whose frequency band does not match the device's current region
  ///
  /// In ru, this message translates to:
  /// **'Другой диапазон'**
  String get radioRegionIncompatibleSection;

  /// Warning text above the incompatible-region section in the full region list
  ///
  /// In ru, this message translates to:
  /// **'Эти регионы работают на другой частоте, чем плата уже настроена. Железо устройства может не поддерживать такой диапазон — связь пропадёт.'**
  String get radioRegionIncompatibleWarning;

  /// Settings row and subscreen title gathering settings meant only for users who understand the consequences
  ///
  /// In ru, this message translates to:
  /// **'Дополнительно'**
  String get settingsAdvancedTitle;

  /// Subtitle of the 'Advanced' settings row, naming what is inside
  ///
  /// In ru, this message translates to:
  /// **'Подключение и регион радио'**
  String get settingsAdvancedSubtitle;

  /// No description provided for @onboardingTitle1.
  ///
  /// In ru, this message translates to:
  /// **'Общайтесь без интернета\nи сотовой связи'**
  String get onboardingTitle1;

  /// No description provided for @onboardingText1.
  ///
  /// In ru, this message translates to:
  /// **'Сообщения идут напрямую между устройствами Meshtastic по радио. Никаких тарифов и вышек — связь работает даже там, где нет сети.'**
  String get onboardingText1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In ru, this message translates to:
  /// **'Нужен Meshtastic-девайс'**
  String get onboardingTitle2;

  /// No description provided for @onboardingText2.
  ///
  /// In ru, this message translates to:
  /// **'Включите девайс и держите его рядом с телефоном. Приложение само подключится к нему по Bluetooth.'**
  String get onboardingText2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In ru, this message translates to:
  /// **'Люди, которым\nвы доверяете'**
  String get onboardingTitle3;

  /// No description provided for @onboardingText3.
  ///
  /// In ru, this message translates to:
  /// **'Обменяйтесь QR-кодами с теми, кому доверяете, и создайте общую беседу для своих.'**
  String get onboardingText3;

  /// No description provided for @onboardingSkip.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In ru, this message translates to:
  /// **'Начать'**
  String get onboardingStart;

  /// Add-options sheet item, empty-state button and add-contact dialog title
  ///
  /// In ru, this message translates to:
  /// **'Добавить контакт'**
  String get addContact;

  /// No description provided for @createChannel.
  ///
  /// In ru, this message translates to:
  /// **'Создать беседу'**
  String get createChannel;

  /// Add-options sheet item that opens the user's own QR card
  ///
  /// In ru, this message translates to:
  /// **'Мой контакт'**
  String get myContact;

  /// Status pill: connected to a Meshtastic device
  ///
  /// In ru, this message translates to:
  /// **'Подключено'**
  String get statusConnected;

  /// No description provided for @statusNoConnection.
  ///
  /// In ru, this message translates to:
  /// **'Нет подключения'**
  String get statusNoConnection;

  /// Status pill: auto-reconnecting after a BLE drop
  ///
  /// In ru, this message translates to:
  /// **'Переподключение…'**
  String get statusReconnecting;

  /// No description provided for @emptyChatsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет чатов'**
  String get emptyChatsTitle;

  /// No description provided for @emptyChatsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте контакт или создайте беседу'**
  String get emptyChatsSubtitle;

  /// No description provided for @contactsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Контакты'**
  String get contactsTitle;

  /// No description provided for @noContactsHint.
  ///
  /// In ru, this message translates to:
  /// **'Нет контактов. Добавьте через +'**
  String get noContactsHint;

  /// Fallback chat header title when the peer/channel is unknown
  ///
  /// In ru, this message translates to:
  /// **'Чат'**
  String get chatFallbackTitle;

  /// Presence line: the DM peer is currently reachable on the mesh
  ///
  /// In ru, this message translates to:
  /// **'В сети'**
  String get online;

  /// Presence line for an offline peer; {time} is a pre-formatted relative time like '5 минут назад'
  ///
  /// In ru, this message translates to:
  /// **'Был(а) в сети {time}'**
  String lastSeen(String time);

  /// No description provided for @editContactTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Изменить контакт'**
  String get editContactTooltip;

  /// No description provided for @aboutChannelTooltip.
  ///
  /// In ru, this message translates to:
  /// **'О беседе'**
  String get aboutChannelTooltip;

  /// No description provided for @backTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get backTooltip;

  /// Placeholder in the chat message input field
  ///
  /// In ru, this message translates to:
  /// **'Сообщение...'**
  String get messageHint;

  /// No description provided for @notDeliveredTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не доставлено'**
  String get notDeliveredTitle;

  /// No description provided for @resendQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Отправить это сообщение ещё раз?'**
  String get resendQuestion;

  /// No description provided for @retrySend.
  ///
  /// In ru, this message translates to:
  /// **'Повторить отправку'**
  String get retrySend;

  /// No description provided for @writeFirstMessage.
  ///
  /// In ru, this message translates to:
  /// **'Напишите первое сообщение!'**
  String get writeFirstMessage;

  /// Centred timeline line for a join announcement seen by this device. {name} is the announced display name, not declinable — kept in the nominative case
  ///
  /// In ru, this message translates to:
  /// **'{name} присоединяется к беседе'**
  String systemEventJoined(String name);

  /// Centred timeline line for a leave announcement seen by this device. {name} is the announced display name, not declinable — kept in the nominative case
  ///
  /// In ru, this message translates to:
  /// **'{name} покидает беседу'**
  String systemEventLeft(String name);

  /// No description provided for @nameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get nameLabel;

  /// Snackbar shown when a DM can't be sent because the peer's public key is unknown
  ///
  /// In ru, this message translates to:
  /// **'Сначала отсканируйте QR-код этого человека — иначе сообщение не дойдёт'**
  String get rescanForSecureChat;

  /// Placeholder shown inside the message bubble instead of an incoming DM's text when it couldn't be decrypted
  ///
  /// In ru, this message translates to:
  /// **'🔒 Не удалось прочитать'**
  String get undecryptableBubble;

  /// Conversation-list preview for a last message that couldn't be decrypted
  ///
  /// In ru, this message translates to:
  /// **'🔒 Не удалось прочитать'**
  String get undecryptablePreview;

  /// Conversation-list preview shown instead of the last message while the secure chat is broken; names the action instead of the diagnosis
  ///
  /// In ru, this message translates to:
  /// **'🔒 Нужно обменяться QR-кодами'**
  String get secureChatBrokenPreview;

  /// Title of the card shown in a DM whose secure chat is broken (peer's keys changed). Names the task, not the failure
  ///
  /// In ru, this message translates to:
  /// **'Нужно обменяться QR-кодами'**
  String get secureChatBrokenTitle;

  /// One-line explanation under the card title: the action first, the likely reason second
  ///
  /// In ru, this message translates to:
  /// **'Покажите друг другу QR-коды — это полминуты. Так бывает, когда у человека новый телефон.'**
  String get secureChatBrokenBody;

  /// Secondary action in the broken-secure-chat card: bring the input field back. Names the chat because the choice is sticky for the whole conversation, not for one message
  ///
  /// In ru, this message translates to:
  /// **'Всё равно писать в этот чат'**
  String get sendAnywayButton;

  /// Key-exchange card, step 1. Impersonal on purpose: Russian would need the genitive for 'the peer's code' and ICU cannot decline names
  ///
  /// In ru, this message translates to:
  /// **'Вы сканируете код собеседника'**
  String get keyExchangeStepScan;

  /// Key-exchange card, step 2. Impersonal, matching step 1
  ///
  /// In ru, this message translates to:
  /// **'Собеседник сканирует ваш код'**
  String get keyExchangeStepShow;

  /// Hint under the scan button: there has to be a code on the other screen before the camera is any use
  ///
  /// In ru, this message translates to:
  /// **'Попросите собеседника открыть «Мой контакт» в приложении'**
  String get keyExchangeAskPeer;

  /// Hint under the key-exchange checklist: the checkmarks arrive on their own, no button to press
  ///
  /// In ru, this message translates to:
  /// **'Галочка появится сама, когда собеседник отсканирует ваш код'**
  String get keyExchangeHint;

  /// Hint under the disabled scan button in the key-exchange card while the radio is not connected: the verify packet cannot leave the phone
  ///
  /// In ru, this message translates to:
  /// **'Сначала подключитесь к устройству'**
  String get connectDeviceFirst;

  /// Snackbar shown in the chat the moment both halves of the key exchange are done. Says what changed instead of naming a 'secure chat' the user has never been introduced to
  ///
  /// In ru, this message translates to:
  /// **'Готово — теперь вы читаете друг друга'**
  String get secureChatRestored;

  /// Button in the key-exchange card that opens the QR scanning screen
  ///
  /// In ru, this message translates to:
  /// **'Отсканировать QR-код'**
  String get scanQrButton;

  /// Button in the key-exchange card that opens the user's own QR code screen
  ///
  /// In ru, this message translates to:
  /// **'Показать мой код'**
  String get showMyQrButton;

  /// Prefix in the conversation list preview for the user's own last message, rendered as 'Я: <text>'
  ///
  /// In ru, this message translates to:
  /// **'Я'**
  String get mePrefix;

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @settingsSectionProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get settingsSectionProfile;

  /// No description provided for @myProfileQrTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мой профиль и QR-код'**
  String get myProfileQrTitle;

  /// No description provided for @shareYourContactSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Поделитесь своим контактом'**
  String get shareYourContactSubtitle;

  /// No description provided for @settingsSectionDevice.
  ///
  /// In ru, this message translates to:
  /// **'Устройство'**
  String get settingsSectionDevice;

  /// Device tile title when connected and the device name is known
  ///
  /// In ru, this message translates to:
  /// **'Подключено: {name}'**
  String connectedToName(String name);

  /// No description provided for @tapToDisconnect.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите чтобы отключиться'**
  String get tapToDisconnect;

  /// Settings section title, the notification-settings screen title and the per-chat notifications switch
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notificationsTitle;

  /// No description provided for @notificationSettingsTile.
  ///
  /// In ru, this message translates to:
  /// **'Настройки уведомлений'**
  String get notificationSettingsTile;

  /// No description provided for @notificationsEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Включены'**
  String get notificationsEnabled;

  /// No description provided for @notificationsDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Выключены'**
  String get notificationsDisabled;

  /// Settings section title and the blocked-nodes screen title
  ///
  /// In ru, this message translates to:
  /// **'Заблокированные'**
  String get settingsSectionBlocked;

  /// No description provided for @blockedNodesTile.
  ///
  /// In ru, this message translates to:
  /// **'Заблокированные устройства'**
  String get blockedNodesTile;

  /// No description provided for @noBlockedNodes.
  ///
  /// In ru, this message translates to:
  /// **'Нет заблокированных устройств'**
  String get noBlockedNodes;

  /// Subtitle of the blocked-nodes tile when there is at least one blocked node
  ///
  /// In ru, this message translates to:
  /// **'Заблокировано: {count}'**
  String blockedCount(int count);

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In ru, this message translates to:
  /// **'Внешний вид'**
  String get settingsSectionAppearance;

  /// No description provided for @languageTile.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get languageTile;

  /// No description provided for @languageSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системный'**
  String get languageSystem;

  /// Endonym — stays 'Русский' in every locale
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// Endonym — stays 'English' in every locale
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @themeTile.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get themeTile;

  /// No description provided for @themeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системная'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeDark;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get settingsSectionAbout;

  /// Subtitle of the About tile
  ///
  /// In ru, this message translates to:
  /// **'v{version} · Open source'**
  String versionOpenSource(String version);

  /// No description provided for @allNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Все уведомления'**
  String get allNotifications;

  /// No description provided for @masterSwitchSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Главный переключатель'**
  String get masterSwitchSubtitle;

  /// No description provided for @sourcesSection.
  ///
  /// In ru, this message translates to:
  /// **'Источники'**
  String get sourcesSection;

  /// No description provided for @directMessages.
  ///
  /// In ru, this message translates to:
  /// **'Личные сообщения'**
  String get directMessages;

  /// No description provided for @channelsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Беседы'**
  String get channelsLabel;

  /// No description provided for @mutedSection.
  ///
  /// In ru, this message translates to:
  /// **'Замьюченные'**
  String get mutedSection;

  /// Button that unmutes a muted conversation
  ///
  /// In ru, this message translates to:
  /// **'Включить'**
  String get unmuteButton;

  /// No description provided for @unblockButton.
  ///
  /// In ru, this message translates to:
  /// **'Разблокировать'**
  String get unblockButton;

  /// No description provided for @saveButton.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get saveButton;

  /// Both the action tile and the share bottom-sheet title
  ///
  /// In ru, this message translates to:
  /// **'Поделиться контактом'**
  String get shareContact;

  /// No description provided for @copyLinkButton.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать ссылку'**
  String get copyLinkButton;

  /// No description provided for @linkCopied.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка скопирована'**
  String get linkCopied;

  /// No description provided for @blockNodeQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Заблокировать?'**
  String get blockNodeQuestion;

  /// No description provided for @blockNodeWarning.
  ///
  /// In ru, this message translates to:
  /// **'Устройство больше не будет отображаться в мессенджере. Сообщения от него будут игнорироваться.'**
  String get blockNodeWarning;

  /// Danger-zone tile and the confirm button in the block dialog
  ///
  /// In ru, this message translates to:
  /// **'Заблокировать'**
  String get blockAction;

  /// No description provided for @deleteContactQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить контакт?'**
  String get deleteContactQuestion;

  /// No description provided for @deleteContactWarning.
  ///
  /// In ru, this message translates to:
  /// **'Контакт «{name}» будет удалён.'**
  String deleteContactWarning(String name);

  /// Confirm button in delete dialogs (contact, channel)
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get deleteAction;

  /// No description provided for @deleteContactAction.
  ///
  /// In ru, this message translates to:
  /// **'Удалить контакт'**
  String get deleteContactAction;

  /// No description provided for @additionalInfoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Дополнительно'**
  String get additionalInfoTitle;

  /// No description provided for @additionalInfoSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'ID устройства, время последнего соединения и другая информация'**
  String get additionalInfoSubtitle;

  /// Label for the Meshtastic device identifier (e.g. !1f8e42c9) shown in contact info and typed manually in the add-contact form
  ///
  /// In ru, this message translates to:
  /// **'ID устройства'**
  String get deviceIdLabel;

  /// Info-row label: when the contact was added
  ///
  /// In ru, this message translates to:
  /// **'Добавлен'**
  String get addedLabel;

  /// No description provided for @lastHeardLabel.
  ///
  /// In ru, this message translates to:
  /// **'Последний раз в сети'**
  String get lastHeardLabel;

  /// No description provided for @offline.
  ///
  /// In ru, this message translates to:
  /// **'Не в сети'**
  String get offline;

  /// Caption under the contact name; {date} is a pre-formatted relative or absolute date like 'сегодня' or '2 мая 2026'
  ///
  /// In ru, this message translates to:
  /// **'Добавлен {date}'**
  String addedOn(String date);

  /// No description provided for @editSheetTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get editSheetTitle;

  /// No description provided for @iconLabel.
  ///
  /// In ru, this message translates to:
  /// **'Иконка'**
  String get iconLabel;

  /// No description provided for @emojiInputHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите любой эмодзи...'**
  String get emojiInputHint;

  /// No description provided for @doneButton.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get doneButton;

  /// No description provided for @shareQrToInvite.
  ///
  /// In ru, this message translates to:
  /// **'Поделитесь QR-кодом чтобы пригласить участника'**
  String get shareQrToInvite;

  /// No description provided for @encryptionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Шифрование'**
  String get encryptionLabel;

  /// No description provided for @encryptionValue.
  ///
  /// In ru, this message translates to:
  /// **'Сквозное шифрование, свой ключ у каждой беседы'**
  String get encryptionValue;

  /// No description provided for @pskLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ключ шифрования'**
  String get pskLabel;

  /// Explains why the channel/conversation info screen has no member list — technically impossible, not an oversight
  ///
  /// In ru, this message translates to:
  /// **'Списка участников нет: в беседе состоит любой, у кого есть её ключ, — приложение не может это отследить.'**
  String get channelMembersInfo;

  /// No description provided for @deleteChannelAction.
  ///
  /// In ru, this message translates to:
  /// **'Удалить беседу'**
  String get deleteChannelAction;

  /// No description provided for @deleteChannelQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить беседу?'**
  String get deleteChannelQuestion;

  /// No description provided for @deleteChannelWarning.
  ///
  /// In ru, this message translates to:
  /// **'Беседа \"{name}\" будет удалена локально. Другие участники продолжат её видеть.'**
  String deleteChannelWarning(String name);

  /// Heading of the join/leave history section on the channel info screen. Deliberately not called a member list — see channelEventsNote
  ///
  /// In ru, this message translates to:
  /// **'Входы и выходы'**
  String get channelEventsTitle;

  /// Short honest note under the join/leave log: explains it is a per-device sighting log, not a member roster, and that entries are unverified self-reports. One or two sentences, not an alarming warning banner
  ///
  /// In ru, this message translates to:
  /// **'Это не список участников: здесь только входы и выходы, которые заметило это устройство, — часть объявлений не доходит. Записи присылают сами участники, и они не проверяются.'**
  String get channelEventsNote;

  /// Empty state for the join/leave history section when no announcements have been seen yet
  ///
  /// In ru, this message translates to:
  /// **'Пока не замечено ни одного входа или выхода'**
  String get channelEventsEmpty;

  /// Add-contact screen title
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get addTitle;

  /// No description provided for @unrecognizedQr.
  ///
  /// In ru, this message translates to:
  /// **'Нераспознанный QR-код'**
  String get unrecognizedQr;

  /// No description provided for @tabScanQr.
  ///
  /// In ru, this message translates to:
  /// **'Скан QR'**
  String get tabScanQr;

  /// No description provided for @tabManual.
  ///
  /// In ru, this message translates to:
  /// **'Вручную'**
  String get tabManual;

  /// No description provided for @cameraError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка камеры: {error}'**
  String cameraError(String error);

  /// No description provided for @pointCameraAtQr.
  ///
  /// In ru, this message translates to:
  /// **'Наведите камеру на QR-код контакта или беседы'**
  String get pointCameraAtQr;

  /// No description provided for @addContactQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Добавить контакт?'**
  String get addContactQuestion;

  /// No description provided for @addChannelQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Добавить беседу?'**
  String get addChannelQuestion;

  /// No description provided for @emojiLabel.
  ///
  /// In ru, this message translates to:
  /// **'Эмодзи'**
  String get emojiLabel;

  /// No description provided for @newChannelTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новая беседа'**
  String get newChannelTitle;

  /// No description provided for @channelNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название беседы'**
  String get channelNameLabel;

  /// No description provided for @channelNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Горная группа'**
  String get channelNameHint;

  /// No description provided for @channelIconLabel.
  ///
  /// In ru, this message translates to:
  /// **'Иконка беседы'**
  String get channelIconLabel;

  /// No description provided for @channelCreateInfo.
  ///
  /// In ru, this message translates to:
  /// **'Беседа создастся с уникальным ключом шифрования. Поделитесь QR-кодом с теми, кого хотите добавить. Учтите: убрать кого-то из беседы нельзя — ключ общий для всех и не меняется.'**
  String get channelCreateInfo;

  /// No description provided for @chooseIconTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите иконку'**
  String get chooseIconTitle;

  /// Default display name on the user's own card before they set a name
  ///
  /// In ru, this message translates to:
  /// **'Я'**
  String get defaultMyName;

  /// No description provided for @askScanQr.
  ///
  /// In ru, this message translates to:
  /// **'Попросите собеседника отсканировать этот QR\nили поделитесь ссылкой'**
  String get askScanQr;

  /// No description provided for @chooseEmojiTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите эмодзи'**
  String get chooseEmojiTitle;

  /// No description provided for @yourNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Ваше имя'**
  String get yourNameHint;

  /// Chat date chip for messages sent today
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get dateToday;

  /// No description provided for @dateYesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get dateYesterday;

  /// Lowercase 'today' used mid-sentence, e.g. 'Добавлен сегодня'
  ///
  /// In ru, this message translates to:
  /// **'сегодня'**
  String get relativeToday;

  /// Relative time: less than a minute ago
  ///
  /// In ru, this message translates to:
  /// **'только что'**
  String get dateJustNow;

  /// No description provided for @minutesAgo.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} минуту назад} few{{count} минуты назад} many{{count} минут назад} other{{count} минуты назад}}'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} час назад} few{{count} часа назад} many{{count} часов назад} other{{count} часа назад}}'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} день назад} few{{count} дня назад} many{{count} дней назад} other{{count} дня назад}}'**
  String daysAgo(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
