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
  String get bluetoothOffTitle => 'Bluetooth is off';

  @override
  String get bluetoothOffHint => 'Turn on Bluetooth to find a nearby device';

  @override
  String get enableBluetooth => 'Turn on Bluetooth';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get connectionErrorTitle => 'Connection error';

  @override
  String get notMeshtasticDevice =>
      'This doesn\'t look like a Meshtastic device. Pick another one from the list.';

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
  String get showAllDevices => 'Show all devices';

  @override
  String get showMeshtasticOnly => 'Meshtastic only';

  @override
  String connectingTo(String name) {
    return 'Connecting to $name...';
  }

  @override
  String get otherDevice => 'Another device';

  @override
  String get pairingHintTitle => 'Pairing request';

  @override
  String get pairingHintBody =>
      'Enter the code shown on your device\'s screen. If no dialog appears, check your notification shade.';

  @override
  String get radioRegionTitle => 'Radio region';

  @override
  String get radioRegionNotSet => 'Not set';

  @override
  String get radioNotConfiguredTitle => 'Device is not set up yet';

  @override
  String get radioNotConfiguredBody =>
      'Until a region is chosen the device stays off the air — nothing you send will go anywhere. The region sets the frequency you are allowed to transmit on where you are.';

  @override
  String get radioRegionChoose => 'Choose region';

  @override
  String get radioRegionHint =>
      'Pick the region for the country you are in. Transmitting on another region\'s frequency breaks local radio regulations.';

  @override
  String get radioRegionCommon => 'Common';

  @override
  String get radioRegionAll => 'All regions';

  @override
  String get radioRegionApplying =>
      'Applying. The device will restart and reconnect on its own.';

  @override
  String get radioRegionFailed =>
      'Could not change the region. Check the connection to your device.';

  @override
  String get radioRegionReading => 'Reading device settings…';

  @override
  String radioRegionUnknownCode(int code) {
    return 'Unknown code ($code)';
  }

  @override
  String radioRegionSuggestBody(String code) {
    return 'Looks like $code suits you. Set up the device?';
  }

  @override
  String get radioRegionSuggestConfirm => 'Set up';

  @override
  String get radioRegionSuggestOther => 'Choose a different region';

  @override
  String get radioRegionChangeWarning =>
      'Anyone whose device is still on the old region will lose contact with you.';

  @override
  String get radioRegionIncompatibleSection => 'Different band';

  @override
  String get radioRegionIncompatibleWarning =>
      'These regions use a different frequency than the device is already set to. The hardware may not support this band — the connection could go silent.';

  @override
  String get settingsAdvancedTitle => 'Advanced';

  @override
  String get settingsAdvancedSubtitle => 'Connection and radio region';

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
  String get statusReconnecting => 'Reconnecting…';

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
  String get rescanForSecureChat =>
      'Scan this person\'s QR code first — otherwise the message won\'t get through';

  @override
  String get undecryptableBubble => '🔒 Couldn\'t be read';

  @override
  String get undecryptablePreview => '🔒 Couldn\'t be read';

  @override
  String get secureChatBrokenPreview => '🔒 Exchange QR codes';

  @override
  String get secureChatBrokenTitle => 'You need to exchange QR codes';

  @override
  String get secureChatBrokenBody =>
      'Show each other your QR codes — it takes half a minute. This happens when someone has a new phone.';

  @override
  String get sendAnywayButton => 'Write in this chat anyway';

  @override
  String get keyExchangeStepScan => 'You scan the other person\'s code';

  @override
  String get keyExchangeStepShow => 'The other person scans your code';

  @override
  String get keyExchangeAskPeer => 'Ask them to open “My contact” in the app';

  @override
  String get keyExchangeHint =>
      'The checkmark appears by itself once they scan your code';

  @override
  String get connectDeviceFirst => 'Connect to your device first';

  @override
  String get secureChatRestored => 'Done — you can read each other now';

  @override
  String get scanQrButton => 'Scan QR code';

  @override
  String get showMyQrButton => 'Show my code';

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
  String get languageTile => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageEnglish => 'English';

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
  String get encryptionValue =>
      'End-to-end encrypted, a unique key per channel';

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

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get relativeToday => 'today';

  @override
  String get dateJustNow => 'just now';

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '$count minute ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '$count hour ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '$count day ago',
    );
    return '$_temp0';
  }
}
