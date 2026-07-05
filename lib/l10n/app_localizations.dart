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

  /// No description provided for @connectionErrorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка подключения'**
  String get connectionErrorTitle;

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
  /// **'Обменяйтесь QR-кодами с теми, кому доверяете, и создайте общий канал для своих.'**
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
  /// **'Создать канал'**
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

  /// No description provided for @emptyChatsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет чатов'**
  String get emptyChatsTitle;

  /// No description provided for @emptyChatsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте контакт или создайте канал'**
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

  /// Banner over a DM from an unknown sender
  ///
  /// In ru, this message translates to:
  /// **'Незнакомец · {nodeId}'**
  String strangerNodeId(String nodeId);

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
  /// **'О канале'**
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

  /// No description provided for @nameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get nameLabel;

  /// Prefix in the conversation list preview for the user's own last message, rendered as 'Я: <text>'
  ///
  /// In ru, this message translates to:
  /// **'Я'**
  String get mePrefix;
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
