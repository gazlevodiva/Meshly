// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get navChats => 'Chats';

  @override
  String get navContacts => 'Contacts';

  @override
  String get navSettings => 'Settings';

  @override
  String get searchHint => 'Search...';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get appTagline => 'People you trust';

  @override
  String get bluetoothPermissionNeeded => 'Bluetooth access is required';

  @override
  String get connectionErrorTitle => 'Connection error';

  @override
  String get checkConnection => 'Check the connection';

  @override
  String get helpTipPoweredOn => 'The device is turned on and charged';

  @override
  String get helpTipBluetoothOn => 'Bluetooth is enabled on your phone';

  @override
  String get helpTipKeepClose => 'Keep the device close to your phone';

  @override
  String get helpTipRestart => 'Restart the device';

  @override
  String get searchAgain => 'Search again';

  @override
  String get connectToDeviceTitle => 'Connect to a device';

  @override
  String get connectToDeviceHint =>
      'Turn on Bluetooth and keep the device nearby';

  @override
  String get stopScan => 'Stop';

  @override
  String get findDevice => 'Find a device';

  @override
  String get scanningNearby => 'Searching for devices nearby...';

  @override
  String get availableDevices => 'Available devices';

  @override
  String get searchingMeshtastic => 'Looking for Meshtastic devices...';

  @override
  String get deviceNotListed => 'Device not in the list?';

  @override
  String connectingTo(String name) {
    return 'Connecting to $name...';
  }

  @override
  String get otherDevice => 'Another device';

  @override
  String get onboardingTitle1 =>
      'Communicate without internet\nor cellular service';

  @override
  String get onboardingText1 =>
      'Messages travel directly between Meshtastic devices over radio. No plans, no cell towers — it works even where there is no coverage.';

  @override
  String get onboardingTitle2 => 'You need a Meshtastic device';

  @override
  String get onboardingText2 =>
      'Turn on the device and keep it near your phone. The app will connect to it over Bluetooth automatically.';

  @override
  String get onboardingTitle3 => 'People\nyou trust';

  @override
  String get onboardingText3 =>
      'Exchange QR codes with people you trust and create a shared channel for your circle.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get addContact => 'Add contact';

  @override
  String get createChannel => 'Create channel';

  @override
  String get myContact => 'My contact';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusNoConnection => 'No connection';

  @override
  String get emptyChatsTitle => 'No chats yet';

  @override
  String get emptyChatsSubtitle => 'Add a contact or create a channel';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get noContactsHint => 'No contacts yet. Add one via +';

  @override
  String get chatFallbackTitle => 'Chat';

  @override
  String strangerNodeId(String nodeId) {
    return 'Stranger · $nodeId';
  }

  @override
  String get online => 'Online';

  @override
  String lastSeen(String time) {
    return 'Last seen $time';
  }

  @override
  String get editContactTooltip => 'Edit contact';

  @override
  String get aboutChannelTooltip => 'About channel';

  @override
  String get backTooltip => 'Back';

  @override
  String get messageHint => 'Message...';

  @override
  String get notDeliveredTitle => 'Not delivered';

  @override
  String get resendQuestion => 'Send this message again?';

  @override
  String get retrySend => 'Resend';

  @override
  String get writeFirstMessage => 'Write the first message!';

  @override
  String get nameLabel => 'Name';

  @override
  String get mePrefix => 'Me';
}
