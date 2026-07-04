# Дизайн-система Meshly

Все визуальные значения приложения централизованы в **`lib/theme/app_theme.dart`**.
Экраны и виджеты не используют «сырые» значения (`Colors.grey`, `fontSize: 12`,
`BorderRadius.circular(8)`) — только именованные токены из темы.

## Две темы

Приложение поддерживает светлую и тёмную темы:

- **`buildLightTheme()`** — светлая (Material 3, сид `Colors.blue`).
- **`buildDarkTheme()`** — тёмная: глубокий графитово-синий фон (`#0B1017`),
  поверхности/карточки `#161D27`, акцент `#2F6BFF`. Схема строится через
  `ColorScheme.fromSeed(brightness: dark)`, но surface-роли и primary
  закреплены вручную, чтобы не уплывать в фиолетово-серые тона.

Обе темы подключены в `MaterialApp` (`theme` / `darkTheme`), а активный режим
(системный / светлый / тёмный) выбирает **`ThemeController`**
(`lib/services/theme_controller.dart`) — ChangeNotifier-синглтон с
персистентностью в SharedPreferences (`theme_mode_v1`). Переключатель — в
Настройках, секция «Внешний вид».

## Токены

| Класс | Что содержит | Примеры |
|-------|--------------|---------|
| `AppColorsExt` | Семантические цвета вне Material ColorScheme, отдельные значения на светлую/тёмную тему (ThemeExtension) | `online`, `textSecondary`, `warning`, `danger`, `dragHandle` |
| `AppSpacing` | Шкала отступов (`s4` = 4px … `s48`) | `AppSpacing.s16`, `AppSpacing.listBottomPadding` |
| `AppRadius` | Радиусы скруглений | `sheet` (20), `input` (24), `island` (28) |
| `AppIconSizes` | Размеры иконок | `mute` (14), `nav` (24), `hero` (72) |
| `AppSizes` | Размеры компонентов и эмодзи | `emojiAvatar` (52), `statusDot` (12), `qrLarge` (220) |
| `AppTextStyles` | Повторяющиеся текстовые стили | `caption`, `subtitle`, `title`, `logo`, `badge` |
| `AppShapes` | Готовые формы | `bottomSheet` |

Семантические цвета читаются **через контекст**: `context.appColors.online`
(расширение `AppColorsContext` возвращает `AppColorsExt` активной темы).
Текстовые стили, чей цвет зависит от темы (`secondary`, `caption`, `hint`…),
— методы, принимающие `BuildContext`: `AppTextStyles.caption(context)`.
Тем-независимые стили (`title`, `logo`, `mono`…) остаются `const`.

Роли Material 3 (`primary`, `error`, `errorContainer`, `primaryContainer`,
`surfaceContainerHighest`…) **не дублируются** в `AppColorsExt` — для них
используется `Theme.of(context).colorScheme`.

## Как добавить новый семантический цвет

1. Добавьте поле в `AppColorsExt` (+ конструктор, `copyWith`, `lerp`).
2. Задайте значение в **обоих** инстансах: `AppColorsExt.light` и
   `AppColorsExt.dark` (для тёмной темы подберите контрастный аналог,
   не копируйте светлое значение вслепую).
3. Используйте в экране через `context.appColors.<токен>`.

## Как поменять дизайн глобально

- **Цвет:** изменить значение в `AppColorsExt.light`/`.dark` (или сид/оверрайды
  в `buildLightTheme()`/`buildDarkTheme()` для всей Material-палитры) —
  обновятся все экраны сразу.
- **Отступ/радиус/шрифт:** аналогично, правится одно значение в соответствующем
  классе токенов.
- **Новое значение:** сначала добавьте именованный токен, затем используйте его
  в экране. Не добавляйте шаг шкалы «на всякий случай» — только реально
  используемые значения.

## Правила для новых экранов

1. Никаких `Colors.*` в `lib/screens/` и `lib/widgets/` (исключение —
   `Colors.transparent`).
2. Никаких числовых `fontSize`, размеров иконок и радиусов — только токены.
3. Экран обязан выглядеть корректно в обеих темах: цвета — только из
   `colorScheme` и `context.appColors`.
4. Ручка bottom sheet — готовый виджет `lib/widgets/sheet_drag_handle.dart`.
5. Форма bottom sheet — `AppShapes.bottomSheet`.

## Референсы

Скриншоты-референсы дизайна храните здесь (`design/`), крупные макеты — в Figma
со ссылкой в этом файле.
