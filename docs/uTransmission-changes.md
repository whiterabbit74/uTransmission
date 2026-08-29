# uTransmission — журнал вмешательств и порядок переноса на новую версию

Документ нужен для одного: когда выйдет новая версия Transmission, быстро получить
из неё такой же uTransmission. Ниже — способ переноса, полный список вмешательств с
якорями в коде и грабли, на которые мы уже наступили.

База: Transmission `a89f4bd5b`. Наши изменения лежат тремя коммитами поверх неё,
`origin` указывает на апстрим `github.com/transmission/transmission`.

## Как переносить

Основной путь — не переписывать правки руками, а перенести коммиты:

```sh
git fetch origin
git rebase origin/main          # или origin/<нужный тег>
./code_style.sh                 # pre-commit хук требует clang-format
```

Если коммит не накладывается, откройте конфликтный файл и найдите вмешательство в
списке ниже по якорю (имени метода) — там написано, что и зачем делалось. Якоря даны
по методам, а не по номерам строк, потому что строки в апстриме сдвигаются.

После переноса — раздел «Проверка» в конце.

## Список вмешательств

### 1. Боковая панель

| Где | Что |
| --- | --- |
| `macosx/SidebarController.h`, `.mm` | Новые файлы целиком. `NSOutlineView` с разделами Transfers и Tags, счётчики торрентов, выбор пишется в существующие `Filter` и `FilterGroup`. |
| `macosx/CMakeLists.txt`, `target_sources` | Добавлены два новых файла в сборку. |
| `Controller.mm`, `updateMainWindow` | Сборка иерархии `NSSplitViewController`. Самое хрупкое место всего форка, см. пункт 2. |
| `Controller.mm`, `toggleSidebar:` | Свёртывание панели с анимацией. |
| `Controller.mm`, `toolbar:itemForItemIdentifier:` | Кнопка `ToolbarItemIdentifierSidebar`. Блок сделан копией соседнего пункта Inspector — если апстрим поменяет способ создания кнопок тулбара, копируйте новый образец оттуда же. |
| `Controller.mm`, `toolbarAllowedItemIdentifiers:`, `toolbarDefaultItemIdentifiers:` | Регистрация кнопки. |
| `Controller.mm`, `validateToolbarItem:` | Состояние кнопки из `fSidebarSplitItem.collapsed`. |
| `Controller.mm`, `applyFilter` | Обновление счётчиков в панели. |

### 2. Инспектор внутри главного окна

| Где | Что |
| --- | --- |
| `Controller.mm`, `updateMainWindow` | Три вложенных `NSSplitViewController`: корневой вертикальный (контент + нижняя панель), горизонтальный (панель + контент), правый вертикальный (список + инспектор). |
| `Controller.mm`, `updateMainWindow` | Нижняя панель берётся как `self.fActionButton.superview`, а корневой view инспектора — как `contentView` его окна. Обе привязки зависят от структуры XIB: если апстрим переверстает `MainMenu.xib` или `InfoWindow.xib`, ломается здесь. |
| `Controller.mm`, `showInfo:` | Вместо показа окна — свёртывание/развёртывание `fInspectorSplitItem`. |
| `Controller.mm`, `clampInspectorHeight` | Новый метод: высота панели по натуральному размеру содержимого, не ниже `kInspectorMinHeight`, не выше `kInspectorMaxHeightFraction` окна. Высоту, выставленную пользователем вручную, не трогает. |
| `Controller.mm`, `validateToolbarItem:`, `applicationWillTerminate:` | Состояние инспектора читается из `fInspectorSplitItem.collapsed`, а не из видимости окна. |
| `Controller.mm`, `awakeFromNib` | Удалён вызов `showInfo:` при запуске: состояние теперь задаётся при создании split item, а `showInfo:` — переключатель, поэтому вызов инвертировал сохранённую настройку. |
| `Controller.mm`, `setWindowSizeToFit` | Ранний выход, когда включена split-компоновка. |
| `InfoWindowController.mm`, `setTab:` | Ветка для встроенного режима: размер окна не меняется, вкладка добавляется в `fTabs.superview` через constraints. Признак встроенности — `containerView.window != self.window`. |
| `InfoWindowController.mm`, `setTab:` | Перед загрузкой view выставляется `embedded` у Activity и Options. Порядок важен: свойство должно быть установлено до первого обращения к `.view`, иначе первый layout-проход пройдёт со значением по умолчанию. |
| `InfoWindowController.mm`, `setInfoForTorrents:` | Принудительное обновление текущего view controller. |
| `InfoActivityViewController.h`, `InfoOptionsViewController.h` | Новое свойство `embedded`. |
| `InfoActivityViewController.mm`, `InfoOptionsViewController.mm`, `checkLayout` | Ширина берётся от собственного view, а не от окна: в split view инспектор уже окна. |
| `InfoActivityViewController.mm`, `InfoOptionsViewController.mm`, `updateWindowLayout` | Во встроенном режиме окно не ресайзится. |
| `InfoActivityViewController.mm`, `viewDidLayout` | Повторный `checkLayout` после того, как Auto Layout выдал реальную ширину. |

### 3. Последовательная загрузка

Важно: сам режим уже реализован в апстримном ядре — piece picker учитывает его в
`peer-mgr-wishlist.cc`, значение сохраняется в resume-файл, RPC-поле
`sequential-download` существует. Мы только открыли к нему доступ.

| Где | Что |
| --- | --- |
| `libtransmission/transmission.h`, рядом с `tr_torrentUseSessionLimits` | Объявления `tr_torrentIsSequentialDownload` и `tr_torrentSetSequentialDownload`. |
| `libtransmission/torrent.cc`, рядом с `tr_torrentUsesSessionLimits` | Их реализация — обёртки над существующими методами `tr_torrent`. |
| `macosx/Torrent.h`, `.mm` | Свойство `sequentialDownload`. |
| `InfoOptionsViewController.mm`, `updateOptions`, `setSequentialDownload:`, `setupInfo` | Чекбокс со смешанным состоянием. |
| `macosx/Base.lproj/InfoOptionsView.xib` | Чекбокс, outlet, action, четыре constraints; высота выросла на 20pt. |
| `Controller.h`, `Controller.mm`, `toggleSequentialDownloadForSelectedTorrents:` | Команда для нескольких выбранных торрентов: включает всем, если хотя бы у одного выключено. |
| `Controller.mm`, `validateMenuItem:` | Состояние пункта меню. |
| `macosx/Base.lproj/MainMenu.xib` | Пункт контекстного меню с иконкой `list.number`. Объявлен в двух местах, см. грабли. |

### 4. Защита от падений при работе со списком

| Где | Что |
| --- | --- |
| `Controller.mm`, `confirmRemoveTorrents:deleteData:` | `closeRemoveTorrent:` откладывается до завершения анимации строк: `fTorrents` очищается сразу, а таблица ещё читает `Torrent` в animation callback. |
| `Controller.mm`, `applicationShouldTerminate:` | Отложенные удаления принудительно выполняются при выходе. |
| `Controller.mm`, `confirmRemoveTorrents:deleteData:` | Повторное удаление уже удалённого объекта отбрасывается через `indexOfObjectIdenticalTo:`. |
| `TorrentTableView.mm`, `reloadDataForRowIndexes:columnIndexes:` | Набор индексов ограничивается текущим количеством строк. Это подстраховка, а не лечение причины: причина — `flushSelectionReload` через `afterDelay:0`, к моменту вызова индексы устарели. |

### 5. Настройки по умолчанию

| Где | Что |
| --- | --- |
| `macosx/Defaults.plist`, `InfoVisible` | `false` → `true`: встроенный инспектор — смысл этой компоновки. У существующих пользователей значение берётся из их профиля, новый дефолт увидят только новые. |

### 6. Название и иконка

| Где | Что |
| --- | --- |
| `macosx/CMakeLists.txt`, `MAC_BUNDLE_NAME` | `Transmission` → `uTransmission`. Задаёт имя бандла, имя исполняемого файла и пути установки, включая оба QuickLook-таргета. |
| `macosx/Info.plist.in`, `CFBundleName`, `CFBundleExecutable` | Литералы заменены на `@MAC_BUNDLE_NAME@`, чтобы имя жило в одном месте. `CFBundleExecutable` обязан совпадать с именем бинарника, которое даёт `OUTPUT_NAME`. |
| `macosx/Base.lproj/MainMenu.xib` | Заголовок главного окна, меню приложения и пункты About / Hide / Quit, а также пункт главного окна в меню Window. |
| `macosx/Images/Images.xcassets/AppIcon.appiconset/*.png` | Десять размеров иконки (16, 32, 128, 256, 512 в 1x и 2x), нарезаны из мастера 1024×1024 через `sips -Z`. `actool` собирает из них `AppIcon.icns` при сборке. |

Что осталось нетронутым намеренно:

- `CFBundleIdentifier` — по-прежнему `org.m0k.transmission`. Менять нельзя: к нему привязаны настройки и список торрентов, при смене пользователь теряет свой профиль.
- `frameAutosaveName="TransmissionWindow"` в `MainMenu.xib` — это ключ в настройках, при переименовании потеряется сохранённая геометрия окна.
- `CFBundleHelpBookFolder`, `CFBundleHelpBookName`, пункты Transmission Help и Transmission Homepage — указывают на справку и сайт апстрима, что для форка честно.
- `macosx/Images/Transmission_Tahoe.icon` — новый формат Icon Composer, в CMake-сборке не используется. Если апстрим начнёт его подключать, иконку надо будет заменить и там.

## Проверка после переноса

Сборка:

```sh
cmake -B build -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Debug -DENABLE_MAC=ON \
    -DENABLE_QT=OFF -DENABLE_GTK=OFF -DENABLE_TESTS=OFF -DENABLE_CLI=OFF \
    -DENABLE_DAEMON=OFF -DENABLE_UTILS=OFF
cmake --build build -j 8
open build/macosx/Transmission.app
```

Что смотреть глазами:

1. Приложение запускается без исключений AppKit, называется `uTransmission.app`, в меню и в Dock — новая иконка.
2. Боковая панель: разделы Transfers и Tags, счётчики совпадают с содержимым списка, выбор фильтрует список.
3. Кнопка боковой панели в тулбаре видна на **светлой** теме и подсвечивается при включении.
4. Инспектор открыт при первом запуске и занимает высоту содержимого, а не всё окно.
5. Переключение всех шести вкладок инспектора; Activity и Options меняют ориентацию по ширине панели, а не окна.
6. Контекстное меню торрента: иконки есть у **всех** пунктов, включая Download Sequentially.
7. Чекбокс Download pieces sequentially для одного и для нескольких торрентов, включая смешанное состояние.
8. Удаление торрента сразу после другого удаления — без падения.
9. Закрыть приложение с открытым и закрытым инспектором, проверить, что состояние восстанавливается (`defaults read org.m0k.transmission InfoVisible`).

## Грабли

1. **SF Symbol в `MainMenu.xib` объявляется дважды.** В самом `menuItem` через `secondaryImage="…" catalog="system"` и в блоке `<resources>` в конце файла. Если добавить только первое, иконки пропадают во **всём** меню, а не только у нового пункта. Размер в `<resources>` берётся из `NSImage(systemSymbolName:).size`.
2. **`fTabs` в инспекторе — это `NSSegmentedControl`.** Вызовы `setLabel:forSegment:` и `setImageScaling:forSegment:` в `awakeFromNib` роняют запуск: AppKit уходит в `setImagePosition:` у `NSSegmentedCell`, которого там нет. Вкладки иконочные, подписи заданы в xib — ничего дополнительно ставить не нужно.
3. **`dist/msi` удалять нельзя.** Корневой `CMakeLists.txt` делает `add_subdirectory(dist/msi)`, без этих файлов ломается конфигурация сборки под Windows.
4. **pre-commit хук проверяет clang-format.** Перед коммитом `./code_style.sh`, иначе коммит отклоняется.
5. **Gatekeeper и `Sparkle.framework`.** Если папку с исходниками принесли AirDrop'ом или скачали архивом, на файлах висит `com.apple.quarantine`. Сборка прописывает rpath прямо в дерево исходников и грузит фреймворк оттуда, поэтому при запуске появляется «Apple could not verify Sparkle.framework». Лечится `xattr -dr com.apple.quarantine .`; через `git clone` проблема не возникает.
6. **`preferredThicknessFraction` не работает** для вложенного `NSSplitViewItem` при первичной раскладке — панель получает всю доступную высоту. Высоту надо задавать явно и после того, как у сплита появился фрейм.
7. **Не определяйте встроенность по `superview`/`window.contentViewController`.** Такое условие истинно и для обычного окна, из-за чего отдельное окно инспектора перестаёт менять размер. Используйте явный флаг.
8. **`showInfo:` — переключатель.** Не вызывайте его для применения сохранённого состояния, иначе состояние инвертируется.

## Известные незакрытые места

- `clampInspectorHeight` вызывается один раз через `dispatch_async` и молча выходит, если у сплита ещё нулевой фрейм. Надёжнее вызывать после `makeKeyAndOrderFront:`.
- Обрезание индексов в `TorrentTableView.mm` маскирует причину, а не устраняет её.
- Ширина и состояние раскрытия боковой панели между запусками не сохраняются.
- Строка `Download Sequentially` в `MainMenu.xib` не заведена в локализации.
- `fPendingTorrentRemovals` — словарь, а не очередь: порядок удалений не гарантирован. Для независимых торрентов это безопасно, но название вводит в заблуждение.
