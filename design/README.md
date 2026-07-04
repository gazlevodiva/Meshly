# Дизайн-система Meshly

Все визуальные значения приложения централизованы в **`lib/theme/app_theme.dart`**.
Экраны и виджеты не используют «сырые» значения (`Colors.grey`, `fontSize: 12`,
`BorderRadius.circular(8)`) — только именованные токены из темы.

## Токены

| Класс | Что содержит | Примеры |
|-------|--------------|---------|
| `AppColors` | Семантические цвета вне Material ColorScheme | `online`, `textSecondary`, `warning`, `danger`, `dragHandle` |
| `AppSpacing` | Шкала отступов (`s4` = 4px … `s48`) | `AppSpacing.s16`, `AppSpacing.listBottomPadding` |
| `AppRadius` | Радиусы скруглений | `sheet` (20), `input` (24), `island` (28) |
| `AppIconSizes` | Размеры иконок | `mute` (14), `nav` (24), `hero` (72) |
| `AppSizes` | Размеры компонентов и эмодзи | `emojiAvatar` (52), `statusDot` (12), `qrLarge` (220) |
| `AppTextStyles` | Повторяющиеся текстовые стили | `caption`, `subtitle`, `title`, `logo`, `badge` |
| `AppShapes` | Готовые формы | `bottomSheet` |

Роли Material 3 (`primary`, `error`, `errorContainer`, `primaryContainer`,
`surfaceContainerHighest`…) **не дублируются** в `AppColors` — для них
используется `Theme.of(context).colorScheme`. Базовая палитра приложения
задаётся сидом `AppColors.seed` в `buildAppTheme()`.

## Как поменять дизайн глобально

- **Цвет:** изменить значение в `AppColors` (или сид `AppColors.seed` для всей
  Material-палитры) — обновятся все экраны сразу.
- **Отступ/радиус/шрифт:** аналогично, правится одно значение в соответствующем
  классе токенов.
- **Новое значение:** сначала добавьте именованный токен, затем используйте его
  в экране. Не добавляйте шаг шкалы «на всякий случай» — только реально
  используемые значения.

## Правила для новых экранов

1. Никаких `Colors.*` в `lib/screens/` и `lib/widgets/` (исключение —
   `Colors.transparent`).
2. Никаких числовых `fontSize`, размеров иконок и радиусов — только токены.
3. Ручка bottom sheet — готовый виджет `lib/widgets/sheet_drag_handle.dart`.
4. Форма bottom sheet — `AppShapes.bottomSheet`.

## Референсы

Скриншоты-референсы дизайна храните здесь (`design/`), крупные макеты — в Figma
со ссылкой в этом файле.
