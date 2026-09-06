/// LoRa regional codes from meshtastic `config.proto` (`RegionCode`).
///
/// The region sets the frequency the device is allowed to transmit on, so it
/// is NEVER set automatically — only via an explicit user choice. Out of the
/// box the board ships with code UNSET (0) and doesn't transmit at all.
library;

class LoraRegion {
  const LoraRegion(this.value, this.code);

  /// Value of the `LoRaConfig.region` field.
  final int value;

  /// Regulatory identifier ("EU_868"). Not translated: it's the code from
  /// the standard, and a person checks it against the board's documentation.
  final String code;

  /// The device isn't configured and stays silent on the air.
  static const int unset = 0;

  /// Regions worth showing first.
  ///
  /// UA_868 is deliberately not included here: in `config.proto` it's marked
  /// `deprecated = true` — offering it first would be wrong, though it's
  /// still kept in [all] (people may have devices already configured to
  /// use it).
  static const List<LoraRegion> common = [
    LoraRegion(3, 'EU_868'),
    LoraRegion(2, 'EU_433'),
    LoraRegion(1, 'US'),
    LoraRegion(14, 'UA_433'),
    LoraRegion(9, 'RU'),
    LoraRegion(6, 'ANZ'),
    LoraRegion(5, 'JP'),
  ];

  /// Full list in `RegionCode` order, without UNSET.
  static const List<LoraRegion> all = [
    LoraRegion(1, 'US'),
    LoraRegion(2, 'EU_433'),
    LoraRegion(3, 'EU_868'),
    LoraRegion(4, 'CN'),
    LoraRegion(5, 'JP'),
    LoraRegion(6, 'ANZ'),
    LoraRegion(7, 'KR'),
    LoraRegion(8, 'TW'),
    LoraRegion(9, 'RU'),
    LoraRegion(10, 'IN'),
    LoraRegion(11, 'NZ_865'),
    LoraRegion(12, 'TH'),
    LoraRegion(13, 'LORA_24'),
    LoraRegion(14, 'UA_433'),
    LoraRegion(15, 'UA_868'),
    LoraRegion(16, 'MY_433'),
    LoraRegion(17, 'MY_919'),
    LoraRegion(18, 'SG_923'),
    LoraRegion(19, 'PH_433'),
    LoraRegion(20, 'PH_868'),
    LoraRegion(21, 'PH_915'),
    LoraRegion(22, 'ANZ_433'),
    LoraRegion(23, 'KZ_433'),
    LoraRegion(24, 'KZ_863'),
    LoraRegion(25, 'NP_865'),
    LoraRegion(26, 'BR_902'),
    LoraRegion(27, 'ITU1_2M'),
    LoraRegion(28, 'ITU2_2M'),
    LoraRegion(29, 'EU_866'),
    LoraRegion(30, 'EU_874'),
    LoraRegion(31, 'EU_917'),
    LoraRegion(32, 'EU_N_868'),
    LoraRegion(33, 'ITU3_2M'),
    LoraRegion(34, 'ITU1_70CM'),
    LoraRegion(35, 'ITU2_70CM'),
    LoraRegion(36, 'ITU3_70CM'),
    LoraRegion(37, 'ITU2_125CM'),
  ];

  /// Region code by field value, or null for UNSET and unknown values
  /// (newer firmware may send a code we don't know about yet).
  static String? codeOf(int value) {
    for (final r in all) {
      if (r.value == value) return r.code;
    }
    return null;
  }

  /// Phone's country (ISO 3166-1 alpha-2) → region, if it's unambiguous for
  /// that country. A missing key or a null value means the country is
  /// unknown, or it has several equally valid regional options and guessing
  /// is not allowed (see Kazakhstan below).
  ///
  /// Source: `RegionCode` (`meshtastic/protobufs` → `config.proto`) and the
  /// firmware's actual frequency table (`meshtastic/firmware` →
  /// `src/mesh/RadioInterface.cpp`, the `regions[]` array).
  static const Map<String, String> _suggestionByCountry = {
    // ── Europe (ETSI EN 300 220, 868 MHz band) ──────────────────────────
    // Except for countries for which Meshtastic has a dedicated code
    // (Ukraine, Russia, Kazakhstan) — those get separate entries below.
    'AD': 'EU_868',
    'AL': 'EU_868',
    'AT': 'EU_868',
    'BA': 'EU_868',
    'BE': 'EU_868',
    'BG': 'EU_868',
    'CH': 'EU_868',
    'CY': 'EU_868',
    'CZ': 'EU_868',
    'DE': 'EU_868',
    'DK': 'EU_868',
    'EE': 'EU_868',
    'ES': 'EU_868',
    'FI': 'EU_868',
    'FR': 'EU_868',
    'GR': 'EU_868',
    'HR': 'EU_868',
    'HU': 'EU_868',
    'IE': 'EU_868',
    'IS': 'EU_868',
    'IT': 'EU_868',
    'LI': 'EU_868',
    'LT': 'EU_868',
    'LU': 'EU_868',
    'LV': 'EU_868',
    'MC': 'EU_868',
    'MD': 'EU_868',
    'ME': 'EU_868',
    'MK': 'EU_868',
    'MT': 'EU_868',
    'NL': 'EU_868',
    'NO': 'EU_868',
    'PL': 'EU_868',
    'PT': 'EU_868',
    'RO': 'EU_868',
    'RS': 'EU_868',
    'SE': 'EU_868',
    'SI': 'EU_868',
    'SK': 'EU_868',
    'SM': 'EU_868',
    'VA': 'EU_868',
    'XK': 'EU_868',
    // UK: post-Brexit regulation stayed within the same ETSI 868 MHz band
    // (there's no separate RegionCode for the UK).
    'GB': 'EU_868',

    // ── US / Canada — shared 902-928 MHz ISM band ───────────────────────
    'US': 'US',
    'CA': 'US',

    // ── Australia / New Zealand ──────────────────────────────────────────
    'AU': 'ANZ',
    'NZ': 'ANZ',

    // ── Asia with a dedicated code ───────────────────────────────────────
    'JP': 'JP',
    'KR': 'KR',
    'TW': 'TW',
    'IN': 'IN',
    'CN': 'CN',
    'TH': 'TH',
    'SG': 'SG_923',
    'NP': 'NP_865',

    // ── South America ────────────────────────────────────────────────────
    'BR': 'BR_902',

    // ── CIS ───────────────────────────────────────────────────────────────
    'RU': 'RU',
    // UA_868 is marked deprecated in config.proto — we suggest the current
    // UA_433 instead of the deprecated code.
    'UA': 'UA_433',
    // Kazakhstan is DELIBERATELY not in this list: it has two equally valid
    // codes (KZ_433 and KZ_863, both valid under regulation), there's no
    // unambiguous choice — see suggestedFor.
  };

  /// Region matching the phone's country (ISO 3166-1 alpha-2, e.g. 'ES'), or
  /// null if the country is unknown or has no unambiguous region for it
  /// (e.g. Kazakhstan — both KZ_433 and KZ_863 are valid).
  static LoraRegion? suggestedFor(String? countryCode) {
    if (countryCode == null) return null;
    final code = _suggestionByCountry[countryCode.toUpperCase()];
    if (code == null) return null;
    for (final r in all) {
      if (r.code == code) return r;
    }
    return null; // should never happen: the code always comes from all
  }

  /// The region's band in MHz, derived from its code ('EU_868' → 868), or
  /// null if a band can't be derived from the code.
  ///
  /// Sources: `RegionCode` (`meshtastic/protobufs` → `config.proto`, the
  /// numbers are baked into the code names themselves) and the `regions[]`
  /// table in `meshtastic/firmware` → `src/mesh/RadioInterface.cpp` (for
  /// codes without a number in the name, and as a sanity check of the
  /// nominal value for the rest).
  static int? bandOf(String code) {
    // LORA_24 is a special case: the "24" suffix here is not MHz, it's the
    // name of the 2.4 GHz band (the WLAN band for SX128x chips): the
    // firmware assigns it 2400.0-2483.5 MHz (RDEF(LORA_24, 2400.0f,
    // 2483.5f, ...)).
    if (code == 'LORA_24') return 2400;

    // An explicit number after the last '_' in the code itself — that's how
    // the region names itself (EU_868 → 868, UA_433 → 433, EU_N_868 → 868,
    // KZ_863 → 863). The suffix has to be PURELY digits: amateur ITU-band
    // codes (ITU1_2M, ITU2_70CM, ITU2_125CM…) also have a suffix that looks
    // like a number, but it denotes a wavelength, not MHz — their band
    // isn't implemented by the firmware at all yet (no RDEF entry), so we
    // return null for them instead of guessing from the suffix's leading
    // digits.
    final suffix = code.split('_').last;
    if (RegExp(r'^\d+$').hasMatch(suffix)) {
      return int.parse(suffix);
    }

    // Codes without a number in the name — the ISM band's nominal value
    // from the firmware's actual frequencies (see the link in this
    // method's doc above). This lists the band's nominal name, not the
    // exact freqStart/freqEnd:
    const named = {
      'US': 915, // 902.0-928.0 MHz (US915)
      'CN': 470, // 470.0-510.0 MHz (CN470)
      'JP': 920, // 920.5-923.5 MHz
      'ANZ': 915, // 915.0-928.0 MHz (AU915)
      'KR': 920, // 920.0-923.0 MHz
      'TW': 920, // 920.0-925.0 MHz
      'RU': 868, // 868.7-869.2 MHz
      'IN': 865, // 865.0-867.0 MHz (IN865)
      'TH': 920, // 920.0-925.0 MHz
    };
    return named[code];
  }

  /// Regions worth suggesting for a board whose current region is
  /// [currentRegion]: those whose band matches the current one's band.
  /// If the current region is UNSET, or its band can't be determined —
  /// returns the whole [all] list: the board hasn't shown itself to be
  /// anything yet (or we don't know what it can do), so there's nothing to
  /// narrow down.
  ///
  /// This guards against switching the region to an incompatible band: a
  /// board already operating on some band is physically built for exactly
  /// that band — a European Heltec's hardware (antenna, matching circuits)
  /// is designed for 868 MHz and can't transmit properly on 433.
  static List<LoraRegion> compatibleWith(int currentRegion) {
    if (currentRegion == unset) return all;
    final currentCode = codeOf(currentRegion);
    if (currentCode == null) return all;
    final band = bandOf(currentCode);
    if (band == null) return all;
    return all.where((r) => bandOf(r.code) == band).toList();
  }
}
