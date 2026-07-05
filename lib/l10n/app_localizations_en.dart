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

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionProfile => 'Profile';

  @override
  String get myProfileQrTitle => 'My profile & QR code';

  @override
  String get shareYourContactSubtitle => 'Share your contact with others';

  @override
  String get settingsSectionDevice => 'Device';

  @override
  String connectedToName(String name) {
    return 'Connected: $name';
  }

  @override
  String get tapToDisconnect => 'Tap to disconnect';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationSettingsTile => 'Notification settings';

  @override
  String get notificationsEnabled => 'On';

  @override
  String get notificationsDisabled => 'Off';

  @override
  String get settingsSectionBlocked => 'Blocked';

  @override
  String get blockedNodesTile => 'Blocked nodes';

  @override
  String get noBlockedNodes => 'No blocked nodes';

  @override
  String blockedCount(int count) {
    return 'Blocked: $count';
  }

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get themeTile => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String versionOpenSource(String version) {
    return 'v$version · Open source';
  }

  @override
  String get allNotifications => 'All notifications';

  @override
  String get masterSwitchSubtitle => 'Master switch';

  @override
  String get sourcesSection => 'Sources';

  @override
  String get directMessages => 'Direct messages';

  @override
  String get channelsLabel => 'Channels';

  @override
  String get mutedSection => 'Muted';

  @override
  String get unmuteButton => 'Unmute';

  @override
  String get unblockButton => 'Unblock';

  @override
  String get saveButton => 'Save';

  @override
  String get shareContact => 'Share contact';

  @override
  String get copyLinkButton => 'Copy link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get blockNodeQuestion => 'Block this node?';

  @override
  String get blockNodeWarning =>
      'The node will no longer appear in the messenger. Messages from it will be ignored.';

  @override
  String get blockAction => 'Block';

  @override
  String get deleteContactQuestion => 'Delete contact?';

  @override
  String deleteContactWarning(String name) {
    return 'The contact \"$name\" will be deleted.';
  }

  @override
  String get deleteAction => 'Delete';

  @override
  String get deleteContactAction => 'Delete contact';

  @override
  String get additionalInfoTitle => 'Details';

  @override
  String get additionalInfoSubtitle =>
      'Node ID, last connection time and other info';

  @override
  String get addedLabel => 'Added';

  @override
  String get lastHeardLabel => 'Last heard';

  @override
  String get offline => 'Offline';

  @override
  String addedOn(String date) {
    return 'Added $date';
  }

  @override
  String get editSheetTitle => 'Edit';

  @override
  String get iconLabel => 'Icon';

  @override
  String get emojiInputHint => 'Type any emoji...';

  @override
  String get doneButton => 'Done';

  @override
  String slotN(int slot) {
    return 'Slot $slot';
  }

  @override
  String get shareQrToInvite => 'Share this QR code to invite a member';

  @override
  String get encryptionLabel => 'Encryption';

  @override
  String get encryptionValue => 'AES-256, unique key';

  @override
  String get pskLabel => 'Key (PSK)';

  @override
  String get deleteChannelAction => 'Delete channel';

  @override
  String get deleteChannelQuestion => 'Delete channel?';

  @override
  String deleteChannelWarning(String name) {
    return 'The channel \"$name\" will be deleted locally. Other members will still see it.';
  }

  @override
  String get addTitle => 'Add';

  @override
  String get unrecognizedQr => 'Unrecognized QR code';

  @override
  String get tabScanQr => 'Scan QR';

  @override
  String get tabManual => 'Manual';

  @override
  String cameraError(String error) {
    return 'Camera error: $error';
  }

  @override
  String get pointCameraAtQr =>
      'Point the camera at a contact or channel QR code';

  @override
  String get addContactQuestion => 'Add contact?';

  @override
  String get addChannelQuestion => 'Add channel?';

  @override
  String get emojiLabel => 'Emoji';

  @override
  String get newChannelTitle => 'New channel';

  @override
  String get allSlotsBusy => 'All slots are taken (7 channels max)';

  @override
  String get channelNameLabel => 'Channel name';

  @override
  String get channelNameHint => 'Hiking group';

  @override
  String get channelIconLabel => 'Channel icon';

  @override
  String get channelCreateInfo =>
      'The channel will be created with a unique encryption key. Share the channel QR code with the people you want to add.';

  @override
  String get chooseIconTitle => 'Choose an icon';

  @override
  String get defaultMyName => 'Me';

  @override
  String get askScanQr =>
      'Ask the other person to scan this QR\nor share the link';

  @override
  String get chooseEmojiTitle => 'Choose an emoji';

  @override
  String get yourNameHint => 'Your name';
}
