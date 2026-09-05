/// Региональные коды LoRa из meshtastic `config.proto` (`RegionCode`).
///
/// Регион задаёт частоту, на которой устройству разрешено вещать, поэтому он
/// НИКОГДА не выставляется автоматически — только явным выбором пользователя.
/// С завода плата приходит с кодом UNSET (0) и в эфир не передаёт вообще.
library;

class LoraRegion {
  const LoraRegion(this.value, this.code);

  /// Значение поля `LoRaConfig.region`.
  final int value;

  /// Регуляторный идентификатор («EU_868»). Не переводится: это код из
  /// стандарта, по нему человек сверяется с документацией на плату.
  final String code;

  /// Устройство не настроено и молчит в эфире.
  static const int unset = 0;

  /// Регионы, которые стоит показать первыми.
  ///
  /// UA_868 сюда намеренно не входит: в `config.proto` он помечен
  /// `deprecated = true` — предлагать его первым делом неправильно, хотя в
  /// [all] он остаётся (у людей могут быть устройства, уже настроенные на
  /// него).
  static const List<LoraRegion> common = [
    LoraRegion(3, 'EU_868'),
    LoraRegion(2, 'EU_433'),
    LoraRegion(1, 'US'),
    LoraRegion(14, 'UA_433'),
    LoraRegion(9, 'RU'),
    LoraRegion(6, 'ANZ'),
    LoraRegion(5, 'JP'),
  ];

  /// Полный список в порядке `RegionCode`, без UNSET.
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

  /// Код региона по значению поля, или null для UNSET и незнакомых значений
  /// (новая прошивка может прислать код, которого мы ещё не знаем).
  static String? codeOf(int value) {
    for (final r in all) {
      if (r.value == value) return r.code;
    }
    return null;
  }

  /// Страна телефона (ISO 3166-1 alpha-2) → регион, если он для неё
  /// однозначен. Отсутствие ключа или значение null — страна неизвестна,
  /// либо у неё несколько равноправных региональных вариантов и угадывать
  /// нельзя (см. Казахстан ниже).
  ///
  /// Источник — `RegionCode` (`meshtastic/protobufs` → `config.proto`) и
  /// таблица фактических частот прошивки (`meshtastic/firmware` →
  /// `src/mesh/RadioInterface.cpp`, массив `regions[]`).
  static const Map<String, String> _suggestionByCountry = {
    // ── Европа (ETSI EN 300 220, диапазон 868 МГц) ──────────────────────
    // Кроме стран, у которых Meshtastic завёл отдельный код (Украина,
    // Россия, Казахстан) — для них ниже отдельные записи.
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
    // Великобритания: после Brexit регуляторика осталась в рамках того же
    // ETSI-диапазона 868 МГц (нет отдельного кода RegionCode для UK).
    'GB': 'EU_868',

    // ── США / Канада — общий диапазон ISM 902–928 МГц ───────────────────
    'US': 'US',
    'CA': 'US',

    // ── Австралия / Новая Зеландия ───────────────────────────────────────
    'AU': 'ANZ',
    'NZ': 'ANZ',

    // ── Азия с собственным кодом ─────────────────────────────────────────
    'JP': 'JP',
    'KR': 'KR',
    'TW': 'TW',
    'IN': 'IN',
    'CN': 'CN',
    'TH': 'TH',
    'SG': 'SG_923',
    'NP': 'NP_865',

    // ── Южная Америка ─────────────────────────────────────────────────
    'BR': 'BR_902',

    // ── СНГ ──────────────────────────────────────────────────────────────
    'RU': 'RU',
    // UA_868 в config.proto помечен deprecated — предлагаем действующий
    // UA_433, а не устаревший код.
    'UA': 'UA_433',
    // Казахстан НАМЕРЕННО не в этом списке: у него два равноправных кода
    // (KZ_433 и KZ_863, оба валидны по регуляторике), однозначного выбора
    // нет — см. suggestedFor.
  };

  /// Регион, подходящий для страны телефона (ISO 3166-1 alpha-2, например
  /// 'ES'), или null, если страна неизвестна либо для неё нет однозначного
  /// региона (например, Казахстан — валидны и KZ_433, и KZ_863).
  static LoraRegion? suggestedFor(String? countryCode) {
    if (countryCode == null) return null;
    final code = _suggestionByCountry[countryCode.toUpperCase()];
    if (code == null) return null;
    for (final r in all) {
      if (r.code == code) return r;
    }
    return null; // не должно случиться: код всегда берётся из all
  }

  /// Диапазон региона в МГц, выведенный из его кода ('EU_868' → 868),
  /// или null, если из кода диапазон не следует.
  ///
  /// Источники: `RegionCode` (`meshtastic/protobufs` → `config.proto`,
  /// числа зашиты в самих именах кодов) и таблица `regions[]` в
  /// `meshtastic/firmware` → `src/mesh/RadioInterface.cpp` (для кодов без
  /// числа в названии, а также как проверка номинала для остальных).
  static int? bandOf(String code) {
    // LORA_24 — особый случай: суффикс "24" здесь не МГц, а название
    // 2.4-ГГц диапазона (WLAN-полоса для чипов SX128x): прошивка задаёт ему
    // 2400.0–2483.5 МГц (RDEF(LORA_24, 2400.0f, 2483.5f, ...)).
    if (code == 'LORA_24') return 2400;

    // Явное число после последнего '_' в самом коде — так называет себя
    // регион (EU_868 → 868, UA_433 → 433, EU_N_868 → 868, KZ_863 → 863).
    // Суффикс обязан быть ЧИСТО цифрами: у кодов любительских ITU-диапазонов
    // (ITU1_2M, ITU2_70CM, ITU2_125CM…) суффикс тоже похож на число, но
    // означает длину волны, а не МГц — их диапазон прошивкой пока вообще не
    // реализован (нет записи RDEF), поэтому для них возвращаем null, а не
    // угадываем по первым цифрам суффикса.
    final suffix = code.split('_').last;
    if (RegExp(r'^\d+$').hasMatch(suffix)) {
      return int.parse(suffix);
    }

    // Коды без числа в названии — номинал ISM-полосы по фактическим частотам
    // из regions[] прошивки (см. ссылку в доке метода выше). Указано
    // номинальное имя полосы, а не точный freqStart/freqEnd:
    const named = {
      'US': 915, // 902.0–928.0 МГц (US915)
      'CN': 470, // 470.0–510.0 МГц (CN470)
      'JP': 920, // 920.5–923.5 МГц
      'ANZ': 915, // 915.0–928.0 МГц (AU915)
      'KR': 920, // 920.0–923.0 МГц
      'TW': 920, // 920.0–925.0 МГц
      'RU': 868, // 868.7–869.2 МГц
      'IN': 865, // 865.0–867.0 МГц (IN865)
      'TH': 920, // 920.0–925.0 МГц
    };
    return named[code];
  }

  /// Регионы, которые имеет смысл предлагать для платы с текущим регионом
  /// [currentRegion]: те, чей диапазон совпадает с диапазоном текущего.
  /// Если текущий регион — UNSET, или его диапазон определить нельзя —
  /// возвращает весь список [all]: плата ещё ничем себя не проявила
  /// (или мы не знаем, что она умеет), сужать нечего.
  ///
  /// Это защита от смены региона на несовместимый диапазон: плата, уже
  /// работающая на каком-то диапазоне, физически умеет именно его — железо
  /// (антенна, согласующие цепи) европейского Heltec рассчитано на 868 МГц
  /// и не сможет корректно излучать на 433.
  static List<LoraRegion> compatibleWith(int currentRegion) {
    if (currentRegion == unset) return all;
    final currentCode = codeOf(currentRegion);
    if (currentCode == null) return all;
    final band = bandOf(currentCode);
    if (band == null) return all;
    return all.where((r) => bandOf(r.code) == band).toList();
  }
}
