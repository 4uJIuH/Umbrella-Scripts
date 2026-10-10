local TEXT = {
    en = {
        rem_group_main = "General",
        rem_enable = "Enable script",
        rem_enable_tip = "Master switch for every Rem helper",

        rem_group_s1 = "Skill 1: Projectile",
        rem_s1_enable = "Enable",
        rem_s1_key = "Cast key",
        rem_s1_key_tip = "Hold to aim and cast at the best target",
        rem_s1_fov = "Aim FOV",
        rem_s1_fov_tip = "Maximum angle from the crosshair to a target",
        rem_s1_range = "Max range",
        rem_s1_range_tip = "Maximum target search distance",
        rem_s1_hitchance = "Hit chance",
        rem_s1_hitchance_tip = "Cast only above this hit chance,\nlower it to cast more often at dodging targets",
        rem_s1_skip_parry = "Skip protected targets",
        rem_s1_skip_parry_tip = "Do not waste the cast on parrying\nor invulnerable targets",
        rem_s1_bending = "Magic bullet",
        rem_s1_bending_tip = "Fire from a nearby point\nto curve the shot around cover",
        rem_s1_gear_bending = "Magic bullet",
        rem_s1_bend_range = "Bend range",
        rem_s1_bend_range_tip = "How far the shot origin may shift,\nraise it for long range",
        rem_s1_marker = "Mark target",
        rem_s1_marker_tip = "Highlight the Skill 1 target with a rotating frame",
        rem_s1_multi = "Multi-target aim",
        rem_s1_multi_tip = "Aim the pillow where its blast catches\nthe most heroes at the moment of impact",
        rem_s1_gear_multi = "Multi-target aim",
        rem_s1_multi_min = "Min heroes",
        rem_s1_multi_min_tip = "Use group aim only when it catches at least this many",
        rem_s1_multi_radius = "Blast radius",
        rem_s1_multi_radius_tip = "Used when the game does not report the pillow radius",
        rem_text_pillow = "Pillow",
        rem_text_pillow_sub = "Thrown into %d heroes",
        rem_group_ult = "Naptime",
        rem_ult_key = "Naptime key",
        rem_ult_key_tip = "Hold: cast Naptime where the gaze catches\nthe most enemies and keep them in it",
        rem_ult_auto = "Auto cast",
        rem_ult_auto_tip = "Cast on its own when enough enemies are in the gaze",
        rem_gear_ult_auto = "Auto cast",
        rem_ult_auto_count = "Min enemies",
        rem_ult_auto_count_tip = "Enemies in the gaze needed to cast",
        rem_ult_steer = "Hold the gaze",
        rem_ult_steer_tip = "Steer the gaze during the channel\nso nobody slips out before falling asleep",
        rem_gear_ult_steer = "Gaze",
        rem_ult_range = "Gaze range",
        rem_ult_range_tip = "Used when the game does not report the range",
        rem_ult_radius = "Gaze width",
        rem_ult_radius_tip = "Used when the game does not report the radius",
        rem_ult_fov = "Aim FOV",
        rem_ult_fov_tip = "Only aim at enemies within this angle from the crosshair",
        rem_ult_marker = "Mark caught enemies",
        rem_ult_marker_tip = "Frame every enemy that is or will be in the gaze",
        rem_text_nap = "Naptime",
        rem_text_nap_sub = "Caught %d heroes",

        rem_group_s2 = "Skill 2: Attach & Heal",
        rem_s2_enable = "Enable",
        rem_s2_key = "Manual key",
        rem_s2_key_tip = "Hold to aim at the chosen target and attach",
        rem_s2_gear_aim = "Manual aim",
        rem_s2_psilent_fov = "P-Silent angle",
        rem_s2_psilent_fov_tip = "Maximum angle for silent aim",
        rem_s2_smooth = "Smoothing",
        rem_s2_smooth_tip = "Higher values give slower, smoother aim",
        rem_s2_auto = "Automatic mode",
        rem_s2_auto_tip = "Attach on its own,\nwhen off only the manual key works",
        rem_s2_priority = "Ally priority",
        rem_s2_priority_tip = "How to pick the ally to heal",
        rem_s2_priorities_low_hp = "Lowest HP",
        rem_s2_priorities_closest = "Closest",
        rem_s2_ally_hp = "Ally HP threshold",
        rem_s2_ally_hp_tip = "Attach to an ally whose HP is below this",
        rem_s2_ally_range = "Ally range",
        rem_s2_ally_range_tip = "Maximum distance to an ally",
        rem_s2_self_hp = "Self-heal threshold",
        rem_s2_self_hp_tip = "Attach to a nearby ally or trooper\nwhen your HP is below this",
        rem_s2_keep_heal = "Keep healing",
        rem_s2_keep_heal_tip = "Keep jumping until your HP is back up",
        rem_s2_gear_keep = "Keep healing",
        rem_s2_keep_hp = "Stop at HP",
        rem_s2_keep_hp_tip = "Stop jumping once your HP is above this",
        rem_s2_chain = "Heal chain",
        rem_s2_chain_tip = "Skip allies already healed\nand move on to the next one",
        rem_s2_gear_chain = "Heal chain",
        rem_s2_draw_chain = "Mark healed allies",
        rem_s2_draw_chain_tip = "Draw a dot above allies\nalready healed in the chain",
        rem_s2_force_next = "Force next jump",
        rem_s2_force_next_tip = "Turning automatic mode on\njumps right away, even mid-heal",
        rem_s2_auto_alt = "Auto Alt-Cast",
        rem_s2_auto_alt_tip = "Hold Alt-Cast automatically while attached",
        rem_s2_panic = "Panic jump",
        rem_s2_panic_tip = "Jump onto the nearest ally or trooper to become\nuntargetable when you get bursted or drop low",
        rem_s2_gear_panic = "Panic jump",
        rem_s2_panic_hp = "HP threshold",
        rem_s2_panic_hp_tip = "Jump when HP is below this",
        rem_s2_panic_burst = "Burst damage",
        rem_s2_panic_burst_tip = "Jump after losing this share of max HP within 1 s",
        rem_group_items = "Healing Items",
        rem_items_enable = "Enable",
        rem_items_enable_tip = "Use active healing items automatically",
        rem_item_ally_tip = "Cast on the most hurt ally below this HP",
        rem_item_self_tip = "Self-cast when Rem is below this HP",
        rem_item_barrier = "Divine Barrier",
        rem_item_barrier_tip = "Barrier and debuff cleanse on the most hurt ally\nin range, or on Rem when her HP is low",
        rem_item_barrier_gear = "Divine Barrier",
        rem_item_barrier_ally = "Ally HP",
        rem_item_barrier_self = "Rem HP",
        rem_item_ward = "Guardian Ward",
        rem_item_ward_tip = "Barrier on the most hurt ally in range,\nor on Rem when her HP is low",
        rem_item_ward_gear = "Guardian Ward",
        rem_item_ward_ally = "Ally HP",
        rem_item_ward_self = "Rem HP",
        rem_item_beam = "Rescue Beam",
        rem_item_beam_tip = "Heal the most hurt ally in range and Rem,\nor Rem alone when her HP is low",
        rem_item_beam_gear = "Rescue Beam",
        rem_item_beam_ally = "Ally HP",
        rem_item_beam_self = "Rem HP",
        rem_item_rite = "Healing Rite",
        rem_item_rite_tip = "Regen on the most hurt ally in range,\nor on Rem when her HP is low",
        rem_item_rite_gear = "Healing Rite",
        rem_item_rite_ally = "Ally HP",
        rem_item_rite_self = "Rem HP",
        rem_item_nova = "Healing Nova",
        rem_item_nova_tip = "Heal around Rem when enough heroes\nnearby drop below the threshold",
        rem_item_nova_gear = "Healing Nova",
        rem_item_nova_hp = "HP threshold",
        rem_item_nova_hp_tip = "Count a hero as hurt below this HP",
        rem_item_nova_count = "Hurt heroes",
        rem_item_nova_count_tip = "How many hurt heroes in range\nare needed, Rem included",
        rem_item_locket = "Restorative Locket",
        rem_item_locket_tip = "Consume stacks to heal Rem when her HP is low",
        rem_item_locket_gear = "Restorative Locket",
        rem_item_locket_hp = "Rem HP",
        rem_item_locket_hp_tip = "Use when Rem is below this HP",
        rem_item_locket_stacks = "Min stacks",
        rem_item_locket_stacks_tip = "Wait for at least this many stacks",
        rem_group_visuals = "Visuals",
        rem_vis_heal_marker = "Mark heal target",
        rem_vis_heal_marker_tip = "Frame with a cross on the ally Rem jumps to next,\nor on her host while attached",
        rem_vis_panel = "Heal priority panel",
        rem_vis_panel_tip = "Allies in the order Rem will heal them",
        rem_vis_gear_panel = "Panel",
        rem_vis_panel_x = "Position X",
        rem_vis_panel_x_tip = "Horizontal position, % of the screen",
        rem_vis_panel_y = "Position Y",
        rem_vis_panel_y_tip = "Vertical position, % of the screen",
        rem_vis_panel_rows = "Rows",
        rem_vis_panel_rows_tip = "How many allies to list",
        rem_vis_notify = "Notifications",
        rem_vis_notify_tip = "Cards for jumps, attaches, items and helpers",
        rem_vis_gear_notify = "Notifications",
        rem_vis_notify_events = "Events",
        rem_vis_notify_events_tip = "Which events get a card",
        rem_vis_notify_time = "Duration",
        rem_vis_notify_time_tip = "How long a card stays on screen",
        rem_vis_notify_x = "Position X",
        rem_vis_notify_x_tip = "Right edge of the cards, % of the screen",
        rem_vis_notify_y = "Position Y",
        rem_vis_notify_y_tip = "Bottom of the stack, % of the screen",
        rem_text_priority = "HEAL PRIORITY",
        rem_text_next = "NEXT",
        rem_text_host = "HOST",
        rem_text_jump = "Jumping to heal",
        rem_text_self = "Self-heal jump",
        rem_text_attach = "Attached",
        rem_text_item = "Used on %s",
        rem_text_helpers = "Helpers sent",
        rem_text_helpers_casino = "Your little helper is farming the Casino",
        rem_text_chain = "Heal chain reset",
        rem_text_chain_sub = "Every ally can be healed again",
        rem_text_trooper = "Trooper",
        rem_text_rem = "Rem",

        rem_group_s3 = "Skill 3: Lil Helpers",
        rem_s3_enable = "Enable",
        rem_s3_gear = "Lil Helpers",
        rem_s3_delay = "Send delay",
        rem_s3_delay_tip = "Minimum time between helper dispatches",
        rem_s3_targets = "Targets",
        rem_s3_targets_tip = "Where the helpers are sent",
        rem_s3_range = "Scan range",
        rem_s3_range_tip = "Maximum target search distance",
        rem_s3_check_buff = "Skip if buff is active",
        rem_s3_check_buff_tip = "Do not send helpers while an ally\nor trooper nearby already has them",
        rem_s3_gear_buff = "Buff check",
        rem_s3_buff_range = "Check radius",
        rem_s3_buff_range_tip = "Radius to look for an active buff",
        rem_s3_combat_only = "Players in combat only",
        rem_s3_combat_only_tip = "Buff an ally only when an enemy is close",
        rem_s3_gear_combat = "Combat check",
        rem_s3_combat_range = "Enemy distance",
        rem_s3_combat_range_tip = "How close an enemy must be\nto count the ally as fighting",
        rem_s3_stack = "Stack on host",
        rem_s3_stack_tip = "Exploit: hold Alt-Cast to put several helpers on the hero\nRem is attached to, stacking spirit resist and speed",
        rem_s3_gear_stack = "Stack on host",
        rem_s3_stack_count = "Helpers",
        rem_s3_stack_key = "Stack key",
        rem_s3_stack_key_tip = "Hold: Rem jumps onto the ally nearest the crosshair and\nAlt-Casts several helpers onto them (or onto Rem if nobody is there).\nCount is set in Stack on host settings",
        rem_s3_stack_count_tip = "How many helpers to put on one host",
        rem_s3_stack_combat = "Only in combat",
        rem_s3_stack_combat_tip = "Stack only while an enemy is close to the host",
        rem_s3_shop = "Remote quick buy",
        rem_s3_shop_tip = "Send a helper to a shop in range to buy the next\nquick buy item once you have enough souls",
        rem_s3_gear_shop = "Remote quick buy",
        rem_s3_shop_souls = "Min souls",
        rem_s3_shop_souls_tip = "Send a helper once you have at least this many souls",
        rem_s3_shop_enemy = "Use enemy shops",
        rem_s3_shop_enemy_tip = "Exploit: buy through an enemy shop in range\nwhen no own shop is close enough",
        rem_text_shop = "Shopping",
        rem_text_shop_sub = "Helper sent to buy the next item",
        rem_text_panic = "Escape jump",
        rem_text_stack = "Stacked on %s",
    },
    ru = {
        rem_group_main = "Основное",
        rem_enable = "Включить скрипт",
        rem_enable_tip = "Главный переключатель всех функций Рем",

        rem_group_s1 = "Скилл 1: Снаряд",
        rem_s1_enable = "Включить",
        rem_s1_key = "Клавиша каста",
        rem_s1_key_tip = "Удерживайте, чтобы навестись и кастовать\nв лучшую цель",
        rem_s1_fov = "Угол прицеливания",
        rem_s1_fov_tip = "Максимальный угол от прицела до цели",
        rem_s1_range = "Макс. дальность",
        rem_s1_range_tip = "Максимальная дистанция поиска цели",
        rem_s1_hitchance = "Шанс попадания",
        rem_s1_hitchance_tip = "Кастовать только выше этого шанса,\nуменьшите, чтобы чаще бить по уворачивающимся",
        rem_s1_skip_parry = "Пропускать защищённых",
        rem_s1_skip_parry_tip = "Не тратить каст на паррирующих\nи неуязвимых",
        rem_s1_bending = "Магическая пуля",
        rem_s1_bending_tip = "Стрелять из соседней точки,\nчтобы обогнуть укрытие",
        rem_s1_gear_bending = "Магическая пуля",
        rem_s1_bend_range = "Дальность изгиба",
        rem_s1_bend_range_tip = "Насколько может сместиться точка выстрела,\nна дальней дистанции увеличьте",
        rem_s1_marker = "Отмечать цель",
        rem_s1_marker_tip = "Подсвечивать цель Скилла 1 вращающейся рамкой",
        rem_s1_multi = "Мультицель",
        rem_s1_multi_tip = "Целить подушку туда, где взрыв накроет\nбольше всего героев в момент попадания",
        rem_s1_gear_multi = "Мультицель",
        rem_s1_multi_min = "Мин. героев",
        rem_s1_multi_min_tip = "Наводить по группе, только если она накроет столько",
        rem_s1_multi_radius = "Радиус взрыва",
        rem_s1_multi_radius_tip = "Используется, если игра не отдаёт радиус подушки",
        rem_text_pillow = "Подушка",
        rem_text_pillow_sub = "Брошена в героев: %d",
        rem_group_ult = "Naptime",
        rem_ult_key = "Клавиша Naptime",
        rem_ult_key_tip = "Удерживайте: каст туда, где взгляд поймает\nбольше всего врагов, и удержание их в луче",
        rem_ult_auto = "Автокаст",
        rem_ult_auto_tip = "Кастовать самому, когда в луч попадает достаточно врагов",
        rem_gear_ult_auto = "Автокаст",
        rem_ult_auto_count = "Мин. врагов",
        rem_ult_auto_count_tip = "Сколько врагов в луче нужно для каста",
        rem_ult_steer = "Удерживать взгляд",
        rem_ult_steer_tip = "Вести взгляд во время канала,\nчтобы никто не выскочил до усыпления",
        rem_gear_ult_steer = "Взгляд",
        rem_ult_range = "Дальность взгляда",
        rem_ult_range_tip = "Используется, если игра не отдаёт дальность",
        rem_ult_radius = "Ширина взгляда",
        rem_ult_radius_tip = "Используется, если игра не отдаёт радиус",
        rem_ult_fov = "Угол наведения",
        rem_ult_fov_tip = "Наводиться только на врагов в этом угле от прицела",
        rem_ult_marker = "Отмечать пойманных",
        rem_ult_marker_tip = "Рамка на каждом враге, который в луче или попадёт в него",
        rem_text_nap = "Naptime",
        rem_text_nap_sub = "Поймано героев: %d",

        rem_group_s2 = "Скилл 2: Прикрепление и лечение",
        rem_s2_enable = "Включить",
        rem_s2_key = "Ручная клавиша",
        rem_s2_key_tip = "Удерживайте, чтобы навестись на цель\nи прикрепиться",
        rem_s2_gear_aim = "Ручное наведение",
        rem_s2_psilent_fov = "Угол P-Silent",
        rem_s2_psilent_fov_tip = "Максимальный угол для скрытого наведения",
        rem_s2_smooth = "Плавность",
        rem_s2_smooth_tip = "Чем больше, тем плавнее и медленнее наводка",
        rem_s2_auto = "Автоматический режим",
        rem_s2_auto_tip = "Прикрепляться самостоятельно,\nв выключенном виде только по клавише",
        rem_s2_priority = "Приоритет союзника",
        rem_s2_priority_tip = "Как выбирать союзника для лечения",
        rem_s2_priorities_low_hp = "Меньше всего ХП",
        rem_s2_priorities_closest = "Ближайший",
        rem_s2_ally_hp = "Порог ХП союзника",
        rem_s2_ally_hp_tip = "Прикрепляться к союзнику с ХП ниже порога",
        rem_s2_ally_range = "Дальность до союзника",
        rem_s2_ally_range_tip = "Максимальная дистанция до союзника",
        rem_s2_self_hp = "Порог самолечения",
        rem_s2_self_hp_tip = "Прикрепляться к союзнику или крипу рядом,\nкогда ваше ХП ниже порога",
        rem_s2_keep_heal = "Продолжать лечение",
        rem_s2_keep_heal_tip = "Прыгать дальше, пока ХП не восстановится",
        rem_s2_gear_keep = "Продолжать лечение",
        rem_s2_keep_hp = "Остановиться на ХП",
        rem_s2_keep_hp_tip = "Прекратить прыжки, когда ХП выше порога",
        rem_s2_chain = "Цепь лечения",
        rem_s2_chain_tip = "Пропускать уже исцелённых союзников\nи переходить к следующему",
        rem_s2_gear_chain = "Цепь лечения",
        rem_s2_draw_chain = "Отмечать исцелённых",
        rem_s2_draw_chain_tip = "Рисовать точку над союзниками,\nуже исцелёнными в цепи",
        rem_s2_force_next = "Принудительный прыжок",
        rem_s2_force_next_tip = "Включение автоматического режима\nсразу прыгает, даже во время лечения",
        rem_s2_auto_alt = "Авто Alt-Cast",
        rem_s2_auto_alt_tip = "Автоматически удерживать Alt-Cast,\nпока Рем прикреплена",
        rem_s2_panic = "Паник-прыжок",
        rem_s2_panic_tip = "Прыгать на ближайшего союзника или крипа,\nчтобы стать неуязвимой для выбора, под бурстом или при низком ХП",
        rem_s2_gear_panic = "Паник-прыжок",
        rem_s2_panic_hp = "Порог ХП",
        rem_s2_panic_hp_tip = "Прыгать, когда ХП ниже этого",
        rem_s2_panic_burst = "Бурст-урон",
        rem_s2_panic_burst_tip = "Прыгать после потери этой доли макс. ХП за 1 с",
        rem_group_items = "Хил-предметы",
        rem_items_enable = "Включить",
        rem_items_enable_tip = "Автоматически использовать активные хил-предметы",
        rem_item_ally_tip = "Кастовать на самого раненого союзника с ХП ниже порога",
        rem_item_self_tip = "Кастовать на себя, когда ХП Рем ниже порога",
        rem_item_barrier = "Божественный барьер",
        rem_item_barrier_tip = "Барьер и снятие дебаффов с самого раненого\nсоюзника в радиусе или с Рем при низком ХП",
        rem_item_barrier_gear = "Божественный барьер",
        rem_item_barrier_ally = "ХП союзника",
        rem_item_barrier_self = "ХП Рем",
        rem_item_ward = "Заслон стража",
        rem_item_ward_tip = "Барьер на самого раненого союзника в радиусе\nили на Рем при низком ХП",
        rem_item_ward_gear = "Заслон стража",
        rem_item_ward_ally = "ХП союзника",
        rem_item_ward_self = "ХП Рем",
        rem_item_beam = "Спасательный луч",
        rem_item_beam_tip = "Лечит самого раненого союзника в радиусе и Рем,\nили только Рем при низком ХП",
        rem_item_beam_gear = "Спасательный луч",
        rem_item_beam_ally = "ХП союзника",
        rem_item_beam_self = "ХП Рем",
        rem_item_rite = "Обряд лечения",
        rem_item_rite_tip = "Регенерация самому раненому союзнику в радиусе\nили Рем при низком ХП",
        rem_item_rite_gear = "Обряд лечения",
        rem_item_rite_ally = "ХП союзника",
        rem_item_rite_self = "ХП Рем",
        rem_item_nova = "Вспышка исцеления",
        rem_item_nova_tip = "Лечение вокруг Рем, когда достаточно героев\nрядом опустились ниже порога",
        rem_item_nova_gear = "Вспышка исцеления",
        rem_item_nova_hp = "Порог ХП",
        rem_item_nova_hp_tip = "Герой считается раненым ниже этого ХП",
        rem_item_nova_count = "Раненых героев",
        rem_item_nova_count_tip = "Сколько раненых героев в радиусе нужно,\nвключая Рем",
        rem_item_locket = "Живительный медальон",
        rem_item_locket_tip = "Тратить заряды на лечение Рем при низком ХП",
        rem_item_locket_gear = "Живительный медальон",
        rem_item_locket_hp = "ХП Рем",
        rem_item_locket_hp_tip = "Использовать, когда ХП Рем ниже порога",
        rem_item_locket_stacks = "Мин. зарядов",
        rem_item_locket_stacks_tip = "Ждать хотя бы столько зарядов",
        rem_group_visuals = "Визуал",
        rem_vis_heal_marker = "Отмечать цель лечения",
        rem_vis_heal_marker_tip = "Рамка с крестом на союзнике, к которому Рем прыгнет,\nили на носителе, пока она прикреплена",
        rem_vis_panel = "Панель приоритета лечения",
        rem_vis_panel_tip = "Союзники в порядке, в котором Рем будет их лечить",
        rem_vis_gear_panel = "Панель",
        rem_vis_panel_x = "Позиция X",
        rem_vis_panel_x_tip = "Положение по горизонтали, % экрана",
        rem_vis_panel_y = "Позиция Y",
        rem_vis_panel_y_tip = "Положение по вертикали, % экрана",
        rem_vis_panel_rows = "Строк",
        rem_vis_panel_rows_tip = "Сколько союзников показывать",
        rem_vis_notify = "Уведомления",
        rem_vis_notify_tip = "Карточки о прыжках, прикреплении, предметах и помощниках",
        rem_vis_gear_notify = "Уведомления",
        rem_vis_notify_events = "События",
        rem_vis_notify_events_tip = "О каких событиях показывать карточку",
        rem_vis_notify_time = "Длительность",
        rem_vis_notify_time_tip = "Сколько карточка висит на экране",
        rem_vis_notify_x = "Позиция X",
        rem_vis_notify_x_tip = "Правый край карточек, % экрана",
        rem_vis_notify_y = "Позиция Y",
        rem_vis_notify_y_tip = "Низ стопки карточек, % экрана",
        rem_text_priority = "ПРИОРИТЕТ ЛЕЧЕНИЯ",
        rem_text_next = "ДАЛЕЕ",
        rem_text_host = "НОСИТЕЛЬ",
        rem_text_jump = "Прыжок для лечения",
        rem_text_self = "Прыжок для самолечения",
        rem_text_attach = "Прикреплена",
        rem_text_item = "Применено на: %s",
        rem_text_helpers = "Помощники отправлены",
        rem_text_helpers_casino = "Твой малыш качает казино",
        rem_text_chain = "Цепь лечения сброшена",
        rem_text_chain_sub = "Всех союзников снова можно лечить",
        rem_text_trooper = "Крип",
        rem_text_rem = "Рем",

        rem_group_s3 = "Скилл 3: Lil Helpers",
        rem_s3_enable = "Включить",
        rem_s3_gear = "Lil Helpers",
        rem_s3_delay = "Задержка отправки",
        rem_s3_delay_tip = "Минимальное время между отправками помощников",
        rem_s3_targets = "Цели",
        rem_s3_targets_tip = "Куда отправлять помощников",
        rem_s3_range = "Дальность поиска",
        rem_s3_range_tip = "Максимальная дистанция поиска цели",
        rem_s3_check_buff = "Пропускать при активном баффе",
        rem_s3_check_buff_tip = "Не отправлять помощников, если союзник\nили крип рядом уже с ними",
        rem_s3_gear_buff = "Проверка баффа",
        rem_s3_buff_range = "Радиус проверки",
        rem_s3_buff_range_tip = "Радиус поиска активного баффа",
        rem_s3_combat_only = "Только игроки в бою",
        rem_s3_combat_only_tip = "Баффать союзника, только если рядом враг",
        rem_s3_gear_combat = "Проверка боя",
        rem_s3_combat_range = "Дистанция до врага",
        rem_s3_combat_range_tip = "Насколько близко должен быть враг,\nчтобы союзник считался в бою",
        rem_s3_stack = "Стак на носителе",
        rem_s3_stack_tip = "Эксплойт: с зажатым Alt-кастом вешает несколько помощников\nна героя, к которому прикреплена Рем (резист и скорость складываются)",
        rem_s3_gear_stack = "Стак на носителе",
        rem_s3_stack_count = "Помощников",
        rem_s3_stack_key_tip = "Зажми: Рем прыгает на союзника ближе всего к прицелу\nи Alt-кастом вешает на него несколько помощников (или на себя, если никого нет).\nКоличество — в настройках «Стак на носителе»",
        rem_s3_stack_key = "Клавиша стака",
        rem_s3_stack_count_tip = "Сколько помощников вешать на одного носителя",
        rem_s3_stack_combat = "Только в бою",
        rem_s3_stack_combat_tip = "Стакать, только когда рядом с носителем враг",
        rem_s3_shop = "Удалённая быстрая покупка",
        rem_s3_shop_tip = "Отправлять помощника в магазин в радиусе, чтобы купить\nследующий предмет из быстрой покупки, когда хватает душ",
        rem_s3_gear_shop = "Удалённая покупка",
        rem_s3_shop_souls = "Мин. душ",
        rem_s3_shop_souls_tip = "Отправлять помощника, когда душ не меньше этого",
        rem_s3_shop_enemy = "Вражеские магазины",
        rem_s3_shop_enemy_tip = "Эксплойт: покупать через вражеский магазин в радиусе,\nесли своего рядом нет",
        rem_text_shop = "Покупка",
        rem_text_shop_sub = "Помощник отправлен за следующим предметом",
        rem_text_panic = "Прыжок для уклонения",
        rem_text_stack = "Навешены на: %s",
    },
}

local localization = qLocalization.new(TEXT)

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local K = {
    UNIT_METER = 37.7358490566,
    IN_ALT_CAST = (InputBitMask_t and InputBitMask_t.IN_ALT_CAST) or 9007199254740992,
    WORLD_REFRESH = 0.1,

    TRACK_WINDOW = 0.5,
    TRACK_HISTORY = 8,
    TRACK_STALE = 2.0,
    TRACK_MOVING_SPEED = 40,
    TRACK_DIRECTION_WINDOW = 0.6,
    VELOCITY_SMOOTHING = 0.75,
    ACCEL_SMOOTHING = 0.2,

    S1_DEFAULT_SPEED = 1300,
    S1_MIN_SPEED = 500,
    S1_MAX_SPEED = 3000,
    S1_SPEED_REFRESH = 1.0,
    S1_MAX_ACCEL = 600,
    S1_ACCEL_THRESHOLD = 80,
    S1_MAX_LEAD_TIME = 2.0,
    S1_ACCEL_HORIZON = 0.3,
    S1_REFINE_STEPS = 4,
    S1_MIN_LEAD_SCALE = 0.55,
    S1_GRAVITY = 800,
    S1_FLOOR_TRACE = 2000,
    S1_TARGET_RADIUS = 40,
    S1_MAX_STRAFE_SPREAD = 100,
    S1_MAX_AIR_SPREAD = 60,
    S1_AIM_BONE = "spine_2",
    S1_MAX_AIM_BONES = 8,

    BULLET_TRACE_BUDGET = 32,
    BULLET_STALE_TICKS = 8,
    BULLET_RETRY_DELAY = 0.06,
    BULLET_SEARCH_RINGS = 16,

    HEAL_CHAIN_EXPIRE = 20.0,
    NAP_ABILITY = "ability_familiar_ability01",
    NAP_CHANNEL = 3.0,
    NAP_RANGE_PROPS = { "AbilityCastRange", "Range", "GazeRange", "MaxRange", "Distance" },
    NAP_RADIUS_PROPS = { "Radius", "GazeRadius", "AbilityRadius", "Width" },
    NAP_CHANNEL_PROPS = { "AbilityChannelTime", "ChannelDuration", "ChannelTime", "AbilityDuration", "Duration" },
    HEAL_CHAIN_RESET = 2.0,
    HEAL_CAST_HOLD = 0.5,
    HEAL_FORCE_WINDOW = 0.3,
    HEAL_AIM_HEIGHT = 55,
    HEAL_MANUAL_FOV = 20,
    HEAL_ATTACHED_ALLY_HP = 0.90,
    ITEM_LOCK = 0.3,
    ITEM_TARGET_GAP = 1.5,
    ITEM_AIM_HEIGHT = 55,
    ALT_CAST_TAP = 0.06,
    ALT_CAST_TIMEOUT = 1.5,
    NOVA_ITEM = "upgrade_health_nova",
    LOCKET_ITEM = "upgrade_restorative_locket",
    BEAM_ITEM = "upgrade_rescue_beam",
    ITEM_BITS = InputBitMask_t and {
        InputBitMask_t.IN_ITEM1, InputBitMask_t.IN_ITEM2, InputBitMask_t.IN_ITEM3, InputBitMask_t.IN_ITEM4,
    } or {},

    HELPERS_EXECUTE_MASK = 4,
    HELPERS_LOCK_TIME = 0.45,
    HELPERS_RETRY_DELAY = 0.55,
    HELPERS_MAX_RETRY = 8.0,
    HELPERS_MAX_CANDIDATES = 24,
    HELPERS_POINT_BUDGET = 96,
    HELPERS_VIEW_FOV = 45.0,
    HELPERS_MIN_INTERVAL = 0.6,
    HELPERS_TURN_SPEED = 9.0,
    HELPERS_TURN_TOLERANCE = 2.5,
    TURN_SPEED = 12.0,
    TURN_SPEED_FAST = 20.0,
    NAP_STEER_SPEED = 7.0,
    NAP_POINT_SMOOTH = 0.2,
    TURN_TOLERANCE = 3.0,
    STACK_KEY_FOV = 30.0,
    HELPERS_SCAN_CACHE = 0.12,
    HELPERS_SCAN_MOVE = 20.0,
    HELPERS_BUFF_CACHE = 0.15,
    HELPERS_PREFILTER = 150.0,
    HELPERS_IDENTITY_TTL = 2.0,
    HELPERS_DISPATCH_SHOW = 0.45,
    SHOP_CLASSES = { "CCitadel_ShopProp", "C_Citadel_ShopProp", "C_TriggerItemShop" },
    SHOP_RETRY = 20.0,
    SHOP_CONFIRM = 6.0,
    SHOP_AIM_HEIGHT = 60,

    LOOT_GOLD_IDOL = 0,
    LOOT_NEUTRAL_GOLD = 2,
    BREAKABLE_EMPTY = 1,
}

local STATE = {
    STUNNED = 18,
    SILENCED = 27,
    ULTING = 286,
    WASTED = { 19, 217, 1302 },
    PROTECTED = { 19, 1302 },
}

local MOD = {
    ATTACHED = "ability_familiar_attach/attached",
    HOST = "ability_familiar_attach/attached/host",
    CAST_DELAY = "ability_familiar_attach/castdelay",
    MOVING = "ability_familiar_attach/movingtoattach",
    ATTACH_HEAL = "ability_familiar_attach/attachheal",
    LOCKOUT = "ability_familiar_attach/lockout",
}

local HELPER_TARGETS = {
    { id = "Boxes", kind = "breakable", on = true },
    { id = "Gold Statues", kind = "statue", on = true },
    { id = "Sinner's Sacrifice", kind = "sinner", on = true },
    { id = "Standard Bearers", kind = "standard_bearer", on = true },
    { id = "Troopers", kind = "trooper", on = false },
    { id = "Players", kind = "player", on = false },
}

local TARGET_ITEMS = {
    { id = "barrier", item = "upgrade_divine_barrier", ally = 35, self = 30, icon = "\u{f132}" },
    { id = "ward", item = "upgrade_guardian_ward", ally = 45, self = 35, icon = "\u{f3ed}" },
    { id = "beam", item = "upgrade_rescue_beam", ally = 40, self = 30, icon = "\u{f0e7}" },
    { id = "rite", item = "upgrade_health_stimpak", ally = 60, self = 50, icon = "\u{f4be}" },
}

local NOTIFY_EVENTS = {
    { id = "Jumps", kind = "jump" },
    { id = "Attach", kind = "attach" },
    { id = "Items", kind = "item" },
    { id = "Lil Helpers", kind = "helpers" },
    { id = "Chain reset", kind = "chain" },
    { id = "Pillow", kind = "pillow" },
    { id = "Naptime", kind = "nap" },
    { id = "Shop", kind = "shop" },
}

local ui = {}
local cfg = { s3_kinds = {}, vis_events = {} }

do
    local hero = UI.Find("Heroes", "Hero List", "hero_familiar") or UI.Create("Heroes", "Hero List", "hero_familiar")
    local page = hero:Find("Rem Assistant") or hero:Create("Rem Assistant")

    local function named(object, key)
        pcall(localization.Register, object, key)
        return object
    end

    local function group(key, side)
        local name = TEXT.en[key]
        return named(page:Find(name) or page:Create(name, side), key)
    end

    local function gear(widget, key)
        return named(widget:Gear(TEXT.en[key]), key)
    end

    local function slider(g, key, min, max, default, format, icon)
        local widget = g:Slider(key, min, max, default, format)
        widget:Icon(icon)
        return widget
    end

    local g_main = group("rem_group_main", Enum.GroupSide.Left)
    ui.enable = g_main:Switch("rem_enable", true, "\u{f011}")
    ui.enable:ToolTip("rem_enable_tip")

    local g_s1 = group("rem_group_s1", Enum.GroupSide.Left)
    ui.s1_enable = g_s1:Switch("rem_s1_enable", true, "\u{f011}")
    ui.s1_key = g_s1:Bind("rem_s1_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
    ui.s1_key:ToolTip("rem_s1_key_tip")
    ui.s1_fov = slider(g_s1, "rem_s1_fov", 1, 30, 20, "%d°", "\u{f05b}")
    ui.s1_fov:ToolTip("rem_s1_fov_tip")
    ui.s1_range = slider(g_s1, "rem_s1_range", 5, 80, 50, "%d m", "\u{f337}")
    ui.s1_range:ToolTip("rem_s1_range_tip")
    ui.s1_hitchance = slider(g_s1, "rem_s1_hitchance", 10, 100, 35, "%d%%", "\u{f140}")
    ui.s1_hitchance:ToolTip("rem_s1_hitchance_tip")
    ui.s1_skip_parry = g_s1:Switch("rem_s1_skip_parry", true, "\u{f3ed}")
    ui.s1_skip_parry:ToolTip("rem_s1_skip_parry_tip")
    ui.s1_bending = g_s1:Switch("rem_s1_bending", true, "\u{f0e7}")
    ui.s1_bending:ToolTip("rem_s1_bending_tip")
    local gear_bending = gear(ui.s1_bending, "rem_s1_gear_bending")
    ui.s1_bend_range = slider(gear_bending, "rem_s1_bend_range", 5, 30, 25, "%d m", "\u{f1ce}")
    ui.s1_bend_range:ToolTip("rem_s1_bend_range_tip")
    ui.s1_marker = g_s1:Switch("rem_s1_marker", true, "\u{f05b}")
    ui.s1_marker:ToolTip("rem_s1_marker_tip")
    ui.s1_multi = g_s1:Switch("rem_s1_multi", false, "\u{f0c0}")
    ui.s1_multi:ToolTip("rem_s1_multi_tip")
    local gear_multi = gear(ui.s1_multi, "rem_s1_gear_multi")
    ui.s1_multi_min = slider(gear_multi, "rem_s1_multi_min", 2, 5, 2, "%d", "\u{f0c0}")
    ui.s1_multi_min:ToolTip("rem_s1_multi_min_tip")
    ui.s1_multi_radius = slider(gear_multi, "rem_s1_multi_radius", 2, 12, 5, "%d m", "\u{f1ce}")
    ui.s1_multi_radius:ToolTip("rem_s1_multi_radius_tip")

    local g_items = group("rem_group_items", Enum.GroupSide.Left)
    ui.items_enable = g_items:Switch("rem_items_enable", true, "\u{f011}")
    ui.items_enable:ToolTip("rem_items_enable_tip")
    for _, def in ipairs(TARGET_ITEMS) do
        local key = "rem_item_" .. def.id
        local widget = g_items:Switch(key, true, def.icon)
        widget:ToolTip(key .. "_tip")
        local panel = gear(widget, key .. "_gear")
        def.ui = {
            enable = widget,
            ally = slider(panel, key .. "_ally", 5, 95, def.ally, "%d%%", "\u{f0c0}"),
            self = slider(panel, key .. "_self", 5, 95, def.self, "%d%%", "\u{f21e}"),
        }
        def.ui.ally:ToolTip("rem_item_ally_tip")
        def.ui.self:ToolTip("rem_item_self_tip")
        def.cfg = {}
    end
    ui.item_nova = g_items:Switch("rem_item_nova", true, "\u{f479}")
    ui.item_nova:ToolTip("rem_item_nova_tip")
    local gear_nova = gear(ui.item_nova, "rem_item_nova_gear")
    ui.item_nova_hp = slider(gear_nova, "rem_item_nova_hp", 5, 95, 50, "%d%%", "\u{f004}")
    ui.item_nova_hp:ToolTip("rem_item_nova_hp_tip")
    ui.item_nova_count = slider(gear_nova, "rem_item_nova_count", 1, 6, 1, "%d", "\u{f0c0}")
    ui.item_nova_count:ToolTip("rem_item_nova_count_tip")
    ui.item_locket = g_items:Switch("rem_item_locket", true, "\u{f3a5}")
    ui.item_locket:ToolTip("rem_item_locket_tip")
    local gear_locket = gear(ui.item_locket, "rem_item_locket_gear")
    ui.item_locket_hp = slider(gear_locket, "rem_item_locket_hp", 5, 95, 40, "%d%%", "\u{f21e}")
    ui.item_locket_hp:ToolTip("rem_item_locket_hp_tip")
    ui.item_locket_stacks = slider(gear_locket, "rem_item_locket_stacks", 1, 25, 5, "%d", "\u{f5fd}")
    ui.item_locket_stacks:ToolTip("rem_item_locket_stacks_tip")

    local g_vis = group("rem_group_visuals", Enum.GroupSide.Left)
    ui.vis_heal_marker = g_vis:Switch("rem_vis_heal_marker", true, "\u{f21e}")
    ui.vis_heal_marker:ToolTip("rem_vis_heal_marker_tip")
    ui.vis_panel = g_vis:Switch("rem_vis_panel", true, "\u{f0cb}")
    ui.vis_panel:ToolTip("rem_vis_panel_tip")
    local gear_panel = gear(ui.vis_panel, "rem_vis_gear_panel")
    ui.vis_panel_x = slider(gear_panel, "rem_vis_panel_x", 0, 100, 2, "%d%%", "\u{f337}")
    ui.vis_panel_x:ToolTip("rem_vis_panel_x_tip")
    ui.vis_panel_y = slider(gear_panel, "rem_vis_panel_y", 0, 100, 38, "%d%%", "\u{f338}")
    ui.vis_panel_y:ToolTip("rem_vis_panel_y_tip")
    ui.vis_panel_rows = slider(gear_panel, "rem_vis_panel_rows", 2, 6, 4, "%d", "\u{f0cb}")
    ui.vis_panel_rows:ToolTip("rem_vis_panel_rows_tip")
    ui.vis_notify = g_vis:Switch("rem_vis_notify", true, "\u{f0f3}")
    ui.vis_notify:ToolTip("rem_vis_notify_tip")
    local gear_notify = gear(ui.vis_notify, "rem_vis_gear_notify")
    local event_ids = {}
    for i, event in ipairs(NOTIFY_EVENTS) do event_ids[i] = event.id end
    ui.vis_events = gear_notify:MultiCombo("rem_vis_notify_events", event_ids, event_ids)
    ui.vis_events:ToolTip("rem_vis_notify_events_tip")
    ui.vis_notify_time = slider(gear_notify, "rem_vis_notify_time", 1.0, 8.0, 3.0, "%.1f s", "\u{f017}")
    ui.vis_notify_time:ToolTip("rem_vis_notify_time_tip")
    ui.vis_notify_x = slider(gear_notify, "rem_vis_notify_x", 0, 100, 98, "%d%%", "\u{f337}")
    ui.vis_notify_x:ToolTip("rem_vis_notify_x_tip")
    ui.vis_notify_y = slider(gear_notify, "rem_vis_notify_y", 0, 100, 74, "%d%%", "\u{f338}")
    ui.vis_notify_y:ToolTip("rem_vis_notify_y_tip")

    local g_ult = group("rem_group_ult", Enum.GroupSide.Right)
    ui.ult_key = g_ult:Bind("rem_ult_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
    ui.ult_key:ToolTip("rem_ult_key_tip")
    ui.ult_auto = g_ult:Switch("rem_ult_auto", true, "\u{f236}")
    ui.ult_auto:ToolTip("rem_ult_auto_tip")
    ui.ult_auto_count = slider(gear(ui.ult_auto, "rem_gear_ult_auto"), "rem_ult_auto_count", 1, 6, 3, "%d", "\u{f0c0}")
    ui.ult_auto_count:ToolTip("rem_ult_auto_count_tip")
    ui.ult_steer = g_ult:Switch("rem_ult_steer", true, "\u{f06e}")
    ui.ult_steer:ToolTip("rem_ult_steer_tip")
    local gear_gaze = gear(ui.ult_steer, "rem_gear_ult_steer")
    ui.ult_range = slider(gear_gaze, "rem_ult_range", 10, 60, 30, "%d m", "\u{f337}")
    ui.ult_range:ToolTip("rem_ult_range_tip")
    ui.ult_radius = slider(gear_gaze, "rem_ult_radius", 1, 10, 4, "%d m", "\u{f1ce}")
    ui.ult_radius:ToolTip("rem_ult_radius_tip")
    ui.ult_fov = slider(gear_gaze, "rem_ult_fov", 10, 180, 70, "%d°", "\u{f05b}")
    ui.ult_fov:ToolTip("rem_ult_fov_tip")
    ui.ult_marker = g_ult:Switch("rem_ult_marker", true, "\u{f05b}")
    ui.ult_marker:ToolTip("rem_ult_marker_tip")

    local g_s2 = group("rem_group_s2", Enum.GroupSide.Right)
    ui.s2_enable = g_s2:Switch("rem_s2_enable", true, "\u{f011}")
    ui.s2_key = g_s2:Bind("rem_s2_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
    ui.s2_key:ToolTip("rem_s2_key_tip")
    local gear_aim = gear(ui.s2_key, "rem_s2_gear_aim")
    ui.s2_psilent_fov = slider(gear_aim, "rem_s2_psilent_fov", 1, 180, 25, "%d°", "\u{f05b}")
    ui.s2_psilent_fov:ToolTip("rem_s2_psilent_fov_tip")
    ui.s2_smooth = slider(gear_aim, "rem_s2_smooth", 1, 100, 12, "%d", "\u{f1de}")
    ui.s2_smooth:ToolTip("rem_s2_smooth_tip")
    ui.s2_auto = g_s2:Switch("rem_s2_auto", true, "\u{f021}")
    ui.s2_auto:ToolTip("rem_s2_auto_tip")
    ui.s2_priority = g_s2:Combo("rem_s2_priority", { "rem_s2_priorities_low_hp", "rem_s2_priorities_closest" }, 0)
    ui.s2_priority:Icon("\u{f0dc}")
    ui.s2_priority:ToolTip("rem_s2_priority_tip")
    ui.s2_ally_hp = slider(g_s2, "rem_s2_ally_hp", 5, 95, 70, "%d%%", "\u{f004}")
    ui.s2_ally_hp:ToolTip("rem_s2_ally_hp_tip")
    ui.s2_ally_range = slider(g_s2, "rem_s2_ally_range", 5, 60, 30, "%d m", "\u{f337}")
    ui.s2_ally_range:ToolTip("rem_s2_ally_range_tip")
    ui.s2_self_hp = slider(g_s2, "rem_s2_self_hp", 5, 95, 40, "%d%%", "\u{f21e}")
    ui.s2_self_hp:ToolTip("rem_s2_self_hp_tip")
    ui.s2_keep_heal = g_s2:Switch("rem_s2_keep_heal", false, "\u{f0fa}")
    ui.s2_keep_heal:ToolTip("rem_s2_keep_heal_tip")
    local gear_keep = gear(ui.s2_keep_heal, "rem_s2_gear_keep")
    ui.s2_keep_hp = slider(gear_keep, "rem_s2_keep_hp", 10, 100, 95, "%d%%", "\u{f004}")
    ui.s2_keep_hp:ToolTip("rem_s2_keep_hp_tip")
    ui.s2_chain = g_s2:Switch("rem_s2_chain", true, "\u{f0c1}")
    ui.s2_chain:ToolTip("rem_s2_chain_tip")
    local gear_chain = gear(ui.s2_chain, "rem_s2_gear_chain")
    ui.s2_draw_chain = gear_chain:Switch("rem_s2_draw_chain", true, "\u{f06e}")
    ui.s2_draw_chain:ToolTip("rem_s2_draw_chain_tip")
    ui.s2_force_next = g_s2:Switch("rem_s2_force_next", false, "\u{f051}")
    ui.s2_force_next:ToolTip("rem_s2_force_next_tip")
    ui.s2_auto_alt = g_s2:Switch("rem_s2_auto_alt", true, "\u{f2f1}")
    ui.s2_auto_alt:ToolTip("rem_s2_auto_alt_tip")
    ui.s2_panic = g_s2:Switch("rem_s2_panic", true, "\u{f071}")
    ui.s2_panic:ToolTip("rem_s2_panic_tip")
    local gear_panic = gear(ui.s2_panic, "rem_s2_gear_panic")
    ui.s2_panic_hp = slider(gear_panic, "rem_s2_panic_hp", 5, 60, 25, "%d%%", "\u{f004}")
    ui.s2_panic_hp:ToolTip("rem_s2_panic_hp_tip")
    ui.s2_panic_burst = slider(gear_panic, "rem_s2_panic_burst", 10, 80, 30, "%d%%", "\u{f0e7}")
    ui.s2_panic_burst:ToolTip("rem_s2_panic_burst_tip")

    local g_s3 = group("rem_group_s3", Enum.GroupSide.Right)
    ui.s3_enable = g_s3:Switch("rem_s3_enable", true, "\u{f011}")
    local gear_s3 = gear(ui.s3_enable, "rem_s3_gear")
    ui.s3_delay = slider(gear_s3, "rem_s3_delay", 0.0, 1.0, 0.03, "%.2f s", "\u{f017}")
    ui.s3_delay:ToolTip("rem_s3_delay_tip")
    local target_ids, target_defaults = {}, {}
    for _, target in ipairs(HELPER_TARGETS) do
        target_ids[#target_ids + 1] = target.id
        if target.on then target_defaults[#target_defaults + 1] = target.id end
    end
    ui.s3_targets = g_s3:MultiCombo("rem_s3_targets", target_ids, target_defaults)
    ui.s3_targets:Icon("\u{f05b}")
    ui.s3_targets:ToolTip("rem_s3_targets_tip")
    ui.s3_range = slider(g_s3, "rem_s3_range", 5.0, 80.0, 45.0, "%.1f m", "\u{f1ce}")
    ui.s3_range:ToolTip("rem_s3_range_tip")
    ui.s3_check_buff = g_s3:Switch("rem_s3_check_buff", true, "\u{f132}")
    ui.s3_check_buff:ToolTip("rem_s3_check_buff_tip")
    local gear_buff = gear(ui.s3_check_buff, "rem_s3_gear_buff")
    ui.s3_buff_range = slider(gear_buff, "rem_s3_buff_range", 5, 50, 25, "%d m", "\u{f1ce}")
    ui.s3_buff_range:ToolTip("rem_s3_buff_range_tip")
    ui.s3_combat_only = g_s3:Switch("rem_s3_combat_only", true, "\u{f6de}")
    ui.s3_combat_only:ToolTip("rem_s3_combat_only_tip")
    local gear_combat = gear(ui.s3_combat_only, "rem_s3_gear_combat")
    ui.s3_combat_range = slider(gear_combat, "rem_s3_combat_range", 5, 40, 20, "%d m", "\u{f337}")
    ui.s3_combat_range:ToolTip("rem_s3_combat_range_tip")
    ui.s3_stack = g_s3:Switch("rem_s3_stack", false, "\u{f5fd}")
    ui.s3_stack:ToolTip("rem_s3_stack_tip")
    local gear_stack = gear(ui.s3_stack, "rem_s3_gear_stack")
    ui.s3_stack_count = slider(gear_stack, "rem_s3_stack_count", 1, 4, 2, "%d", "\u{f0c0}")
    ui.s3_stack_key = g_s3:Bind("rem_s3_stack_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
    ui.s3_stack_key:ToolTip("rem_s3_stack_key_tip")
    ui.s3_stack_count:ToolTip("rem_s3_stack_count_tip")
    ui.s3_stack_combat = gear_stack:Switch("rem_s3_stack_combat", true, "\u{f71d}")
    ui.s3_stack_combat:ToolTip("rem_s3_stack_combat_tip")
    ui.s3_shop = g_s3:Switch("rem_s3_shop", true, "\u{f07a}")
    ui.s3_shop:ToolTip("rem_s3_shop_tip")
    local gear_shop = gear(ui.s3_shop, "rem_s3_gear_shop")
    ui.s3_shop_souls = slider(gear_shop, "rem_s3_shop_souls", 300, 6400, 800, "%d", "\u{f81c}")
    ui.s3_shop_souls:ToolTip("rem_s3_shop_souls_tip")
    ui.s3_shop_enemy = gear_shop:Switch("rem_s3_shop_enemy", false, "\u{f54c}")
    ui.s3_shop_enemy:ToolTip("rem_s3_shop_enemy_tip")
end

do
    local function set_disabled(widget, disabled)
        pcall(function() widget:Disabled(disabled) end)
    end

    local function refresh_disabled()
        local on = ui.enable:Get()
        local s1 = on and ui.s1_enable:Get()
        local s2 = on and ui.s2_enable:Get()
        local s3 = on and ui.s3_enable:Get()

        set_disabled(ui.s1_enable, not on)
        for _, widget in ipairs({ ui.s1_key, ui.s1_fov, ui.s1_range, ui.s1_hitchance, ui.s1_skip_parry, ui.s1_bending, ui.s1_marker, ui.s1_multi }) do
            set_disabled(widget, not s1)
        end
        set_disabled(ui.s1_bend_range, not s1 or not ui.s1_bending:Get())

        set_disabled(ui.s2_enable, not on)
        for _, widget in ipairs({
            ui.s2_key, ui.s2_psilent_fov, ui.s2_smooth, ui.s2_auto, ui.s2_priority, ui.s2_ally_hp,
            ui.s2_ally_range, ui.s2_self_hp, ui.s2_keep_heal, ui.s2_chain, ui.s2_auto_alt, ui.s2_panic,
        }) do
            set_disabled(widget, not s2)
        end
        set_disabled(ui.s2_force_next, not s2 or not ui.s2_auto:Get())
        set_disabled(ui.s2_keep_hp, not s2 or not ui.s2_keep_heal:Get())
        set_disabled(ui.s2_draw_chain, not s2 or not ui.s2_chain:Get())

        local items = on and ui.items_enable:Get()
        set_disabled(ui.items_enable, not on)
        for _, def in ipairs(TARGET_ITEMS) do
            set_disabled(def.ui.enable, not items)
            set_disabled(def.ui.ally, not items or not def.ui.enable:Get())
            set_disabled(def.ui.self, not items or not def.ui.enable:Get())
        end
        set_disabled(ui.item_nova, not items)
        set_disabled(ui.item_nova_hp, not items or not ui.item_nova:Get())
        set_disabled(ui.item_nova_count, not items or not ui.item_nova:Get())
        set_disabled(ui.item_locket, not items)
        set_disabled(ui.item_locket_hp, not items or not ui.item_locket:Get())
        set_disabled(ui.item_locket_stacks, not items or not ui.item_locket:Get())

        for _, widget in ipairs({ ui.vis_heal_marker, ui.vis_panel, ui.vis_notify, ui.ult_key, ui.ult_auto, ui.ult_steer, ui.ult_marker }) do
            set_disabled(widget, not on)
        end
        set_disabled(ui.ult_auto_count, not on or not ui.ult_auto:Get())
        for _, widget in ipairs({ ui.ult_range, ui.ult_radius, ui.ult_fov }) do
            set_disabled(widget, not on or not ui.ult_steer:Get())
        end
        for _, widget in ipairs({ ui.vis_panel_x, ui.vis_panel_y, ui.vis_panel_rows }) do
            set_disabled(widget, not on or not ui.vis_panel:Get())
        end
        for _, widget in ipairs({ ui.vis_events, ui.vis_notify_time, ui.vis_notify_x, ui.vis_notify_y }) do
            set_disabled(widget, not on or not ui.vis_notify:Get())
        end

        set_disabled(ui.s3_enable, not on)
        set_disabled(ui.s2_panic_hp, not s2 or not ui.s2_panic:Get())
        set_disabled(ui.s2_panic_burst, not s2 or not ui.s2_panic:Get())
        for _, widget in ipairs({ ui.s3_delay, ui.s3_targets, ui.s3_range, ui.s3_check_buff, ui.s3_combat_only, ui.s3_stack, ui.s3_shop }) do
            set_disabled(widget, not s3)
        end
        set_disabled(ui.s3_buff_range, not s3 or not ui.s3_check_buff:Get())
        set_disabled(ui.s3_combat_range, not s3 or not ui.s3_combat_only:Get())
        set_disabled(ui.s3_stack_count, not s3 or not ui.s3_stack:Get())
        set_disabled(ui.s3_stack_combat, not s3 or not ui.s3_stack:Get())
        set_disabled(ui.s3_shop_souls, not s3 or not ui.s3_shop:Get())
        set_disabled(ui.s3_shop_enemy, not s3 or not ui.s3_shop:Get())
    end

    for _, widget in ipairs({
        ui.enable, ui.s1_enable, ui.s1_bending, ui.s2_enable, ui.s2_auto, ui.s2_keep_heal,
        ui.s2_chain, ui.items_enable, ui.item_nova, ui.item_locket, ui.vis_panel, ui.vis_notify, ui.s2_panic, ui.s3_stack, ui.ult_auto, ui.ult_steer, ui.s3_shop, ui.s3_enable, ui.s3_check_buff, ui.s3_combat_only,
    }) do
        pcall(function() widget:SetCallback(refresh_disabled) end)
    end
    for _, def in ipairs(TARGET_ITEMS) do
        pcall(function() def.ui.enable:SetCallback(refresh_disabled) end)
    end
    pcall(refresh_disabled)
end

local function read_menu()
    cfg.enable = ui.enable:Get()

    cfg.s1_enable = ui.s1_enable:Get()
    cfg.s1_key = ui.s1_key:IsDown()
    cfg.s1_fov = ui.s1_fov:Get()
    cfg.s1_range = ui.s1_range:Get() * K.UNIT_METER
    cfg.s1_hitchance = ui.s1_hitchance:Get() / 100.0
    cfg.s1_skip_parry = ui.s1_skip_parry:Get()
    cfg.s1_bending = ui.s1_bending:Get()
    cfg.s1_bend_range = ui.s1_bend_range:Get() * K.UNIT_METER
    cfg.s1_marker = ui.s1_marker:Get()
    cfg.s1_multi = ui.s1_multi:Get()
    cfg.s1_multi_min = ui.s1_multi_min:Get()
    cfg.s1_multi_radius = ui.s1_multi_radius:Get() * K.UNIT_METER

    cfg.s2_enable = ui.s2_enable:Get()
    cfg.s2_key = ui.s2_key:IsDown()
    cfg.s2_psilent_fov = ui.s2_psilent_fov:Get()
    cfg.s2_smooth = ui.s2_smooth:Get()
    cfg.s2_auto = ui.s2_auto:Get()
    cfg.s2_closest_first = ui.s2_priority:Get() == 1
    cfg.s2_ally_hp = ui.s2_ally_hp:Get() / 100.0
    cfg.s2_ally_range = ui.s2_ally_range:Get() * K.UNIT_METER
    cfg.s2_self_hp = ui.s2_self_hp:Get() / 100.0
    cfg.s2_keep_heal = ui.s2_keep_heal:Get()
    cfg.s2_keep_hp = ui.s2_keep_hp:Get() / 100.0
    cfg.s2_chain = ui.s2_chain:Get()
    cfg.s2_draw_chain = ui.s2_draw_chain:Get()
    cfg.s2_force_next = ui.s2_force_next:Get()
    cfg.s2_auto_alt = ui.s2_auto_alt:Get()
    cfg.s2_panic = ui.s2_panic:Get()
    cfg.s2_panic_hp = ui.s2_panic_hp:Get() / 100.0
    cfg.s2_panic_burst = ui.s2_panic_burst:Get() / 100.0

    cfg.items_enable = ui.items_enable:Get()
    for _, def in ipairs(TARGET_ITEMS) do
        def.cfg.on = def.ui.enable:Get()
        def.cfg.ally = def.ui.ally:Get() / 100.0
        def.cfg.self = def.ui.self:Get() / 100.0
    end
    cfg.item_nova = ui.item_nova:Get()
    cfg.item_nova_hp = ui.item_nova_hp:Get() / 100.0
    cfg.item_nova_count = ui.item_nova_count:Get()
    cfg.item_locket = ui.item_locket:Get()
    cfg.item_locket_hp = ui.item_locket_hp:Get() / 100.0
    cfg.item_locket_stacks = ui.item_locket_stacks:Get()

    cfg.vis_heal_marker = ui.vis_heal_marker:Get()
    cfg.ult_key = ui.ult_key:IsDown()
    cfg.ult_auto = ui.ult_auto:Get()
    cfg.ult_auto_count = ui.ult_auto_count:Get()
    cfg.ult_steer = ui.ult_steer:Get()
    cfg.ult_range = ui.ult_range:Get() * K.UNIT_METER
    cfg.ult_radius = ui.ult_radius:Get() * K.UNIT_METER
    cfg.ult_fov = ui.ult_fov:Get()
    cfg.ult_marker = ui.ult_marker:Get()
    cfg.vis_panel = ui.vis_panel:Get()
    cfg.vis_panel_x = ui.vis_panel_x:Get() / 100.0
    cfg.vis_panel_y = ui.vis_panel_y:Get() / 100.0
    cfg.vis_panel_rows = ui.vis_panel_rows:Get()
    cfg.vis_notify = ui.vis_notify:Get()
    cfg.vis_notify_time = ui.vis_notify_time:Get()
    cfg.vis_notify_x = ui.vis_notify_x:Get() / 100.0
    cfg.vis_notify_y = ui.vis_notify_y:Get() / 100.0
    for _, event in ipairs(NOTIFY_EVENTS) do
        cfg.vis_events[event.kind] = ui.vis_events:Get(event.id) == true
    end

    cfg.s3_enable = ui.s3_enable:Get()
    cfg.s3_delay = math.max(0.0, ui.s3_delay:Get())
    cfg.s3_range = ui.s3_range:Get() * K.UNIT_METER
    cfg.s3_check_buff = ui.s3_check_buff:Get()
    cfg.s3_buff_range = ui.s3_buff_range:Get() * K.UNIT_METER
    cfg.s3_combat_only = ui.s3_combat_only:Get()
    cfg.s3_combat_range = ui.s3_combat_range:Get() * K.UNIT_METER
    cfg.s3_stack = ui.s3_stack:Get()
    cfg.s3_stack_count = ui.s3_stack_count:Get()
    cfg.s3_stack_key = ui.s3_stack_key:IsDown()
    cfg.s3_stack_combat = ui.s3_stack_combat:Get()
    cfg.s3_shop = ui.s3_shop:Get()
    cfg.s3_shop_souls = ui.s3_shop_souls:Get()
    cfg.s3_shop_enemy = ui.s3_shop_enemy:Get()
    for _, target in ipairs(HELPER_TARGETS) do
        cfg.s3_kinds[target.kind] = ui.s3_targets:Get(target.id) == true
    end
end

local function write_log(text)
    if type(Log) == "table" and type(Log.Write) == "function" then
        pcall(Log.Write, text)
    else
        pcall(print, text)
    end
end

local Util, Unit, Spell, World, Track = {}, {}, {}, {}, {}
local Aim, Bullet, Skill1, Heal, Helpers = {}, {}, {}, {}, {}
local Items = {}
local Events, Notify, Panel, Hud = {}, {}, {}, {}
local Nap = {}

do
    local function index_field(obj, key) return obj[key] end
    local function call_valid(ent) return ent:valid() end

    function Util.number(value, default)
        if type(value) == "number" then return value end
        local parsed = tonumber(value)
        if parsed ~= nil then return parsed end
        return default or 0.0
    end

    function Util.field(obj, name, default)
        if not obj then return default end
        local ok, value = pcall(index_field, obj, name)
        if not ok or value == nil then return default end
        return value
    end

    function Util.method(obj, name, default, ...)
        if not obj then return default end
        local ok, fn = pcall(index_field, obj, name)
        if not ok or type(fn) ~= "function" then return default end
        local called, value = pcall(fn, obj, ...)
        if not called or value == nil then return default end
        return value
    end

    function Util.call(tbl, name, default, ...)
        if not tbl then return default end
        local fn = tbl[name]
        if type(fn) ~= "function" then return default end
        local ok, value = pcall(fn, ...)
        if not ok or value == nil then return default end
        return value
    end

    function Util.valid(ent)
        if not ent then return false end
        local ok, valid = pcall(call_valid, ent)
        return ok and valid == true
    end

    function Util.now()
        local now = global_vars.curtime()
        if now > 0.0 then return now end
        if game_rules and type(game_rules.game_time) == "function" then
            now = Util.number(game_rules.game_time(), 0.0)
            if now > 0.0 then return now end
        end
        return os.clock()
    end

    function Util.handle(ent)
        return Util.number(Util.method(ent, "get_handle", 0), 0)
    end

    function Util.uid(ent)
        local index = Util.method(ent, "get_index", nil)
        if index then return Util.number(index, 0) end
        return Util.handle(ent)
    end

    function Util.origin(ent)
        return Util.method(ent, "get_origin", nil)
    end

    function Util.has_any(lower, keywords)
        for i = 1, #keywords do
            if lower:find(keywords[i], 1, true) then return true end
        end
        return false
    end

    function Util.text_has_any(text, keywords)
        if type(text) ~= "string" or text == "" then return false end
        return Util.has_any(text:lower(), keywords)
    end

    function Util.clamp(value, min_value, max_value)
        if value < min_value then return min_value end
        if value > max_value then return max_value end
        return value
    end

    function Util.latency()
        if not net_channel or type(net_channel.latency) ~= "function" then return 0.0 end
        local ok, latency = pcall(net_channel.latency)
        return ok and math.max(0.0, Util.number(latency, 0.0)) or 0.0
    end

    local reported = {}

    -- Smoothly turn only the hero (camera untouched) towards a point; true once it faces it.
    function Util.face(cmd, point, speed)
        local common = rawget(_G, "DLCommon")
        if not common or not common.turn_to or not point then return true end
        local ok, done = pcall(common.turn_to, cmd, point, speed or K.TURN_SPEED, K.TURN_TOLERANCE)
        return not ok or done
    end

    function Util.safe(name, fn, ...)
        local previous = rawget(_G, "DL_MODULE")
        rawset(_G, "DL_MODULE", "rem." .. name)
        local ok, err = pcall(fn, ...)
        rawset(_G, "DL_MODULE", previous)
        if not ok and reported[name] ~= err then
            reported[name] = err
            write_log("[Rem] " .. name .. " failed: " .. tostring(err))
        end
        return ok
    end
end

function Events.emit(kind, entity, extra)
    Util.safe("notify", Notify.push, kind, entity, extra)
end

do
    function Unit.hp(entity)
        if not entity or not entity:valid() then return 1.0 end
        local max_health = entity.m_iMaxHealth
        if not max_health or max_health <= 0 then
            max_health = entity:get_max_health()
        end
        if not max_health or max_health <= 0 then return 1.0 end
        return Util.clamp((entity.m_iHealth or 0) / max_health, 0.0, 1.0)
    end

    function Unit.has_state(entity, state)
        return entity and entity:valid() and entity:has_modifier_state(state) == true
    end

    function Unit.has_any_state(entity, states)
        for _, state in ipairs(states) do
            if Unit.has_state(entity, state) then return true end
        end
        return false
    end

    function Unit.on_ground(entity)
        return ((entity.m_fFlags or 0) % 2) == 1
    end

    function Unit.bone(entity, primary, fallback)
        if not entity or not entity:valid() then return nil end
        return entity:get_bone_pos(primary)
            or (fallback and entity:get_bone_pos(fallback))
            or entity:get_origin()
    end

    function Unit.fov_to(position)
        return utils.get_fov(utils.get_camera_angles(), utils.calc_angle(utils.get_camera_pos(), position))
    end

    function Unit.is_active_object(ent)
        if not Util.valid(ent) then return false end
        if ent:is_dormant() or not ent:is_alive() then return false end
        if Util.field(ent, "m_bActive", true) == false then return false end
        if Util.field(ent, "m_bVacuumFinished", false) == true then return false end
        if Util.field(ent, "m_bBroken", false) == true then return false end
        if Util.field(ent, "m_bPermanentlyBroken", false) == true then return false end
        local health = Util.field(ent, "m_iHealth", nil)
        if health ~= nil and Util.number(health, 0) <= 0 then return false end
        local life_state = Util.field(ent, "m_lifeState", nil)
        if life_state ~= nil and Util.number(life_state, 0) ~= 0 then return false end
        local model_scale = Util.field(ent, "m_flModelScale", nil)
        if model_scale ~= nil and Util.number(model_scale, 1.0) <= 0.01 then return false end
        return true
    end

    function Unit.center(ent, origin)
        local collision = Util.field(ent, "m_pCollision", nil)
        local mins = Util.field(collision, "m_vecMins", nil)
        local maxs = Util.field(collision, "m_vecMaxs", nil)
        if not mins or not maxs then return origin end
        local ok, center = pcall(function()
            return Vector(
                origin.x + (mins.x + maxs.x) * 0.5,
                origin.y + (mins.y + maxs.y) * 0.5,
                origin.z + (mins.z + maxs.z) * 0.5
            )
        end)
        return ok and center or origin
    end
end

do
    function Spell.by_slot(pawn, slot)
        return pawn and pawn:get_ability_by_slot(slot) or nil
    end

    function Spell.ready(ability)
        return ability ~= nil and ability:valid() and ability:can_be_executed() == 0
    end

    function Spell.attach(pawn)
        local ability = Spell.by_slot(pawn, 1)
        if ability and ability:valid() then return ability end
        return Spell.by_slot(pawn, EAbilitySlots_t.ESlot_Signature_2)
    end

    function Spell.helpers(pawn)
        if not pawn or not pawn:valid() then return nil end
        local ability = Util.method(pawn, "get_ability_by_slot", nil, 2)
        if Util.valid(ability) then return ability end
        ability = Util.method(pawn, "get_ability", nil, "ability_familiar_helpinghands")
        if Util.valid(ability) then return ability end
        return nil
    end

    local SPEED_PROPERTIES = { "ProjectileSpeed", "BulletSpeed", "m_flBulletSpeed", "m_flProjectileSpeed" }

    local function positive(ok, value)
        if ok and type(value) == "number" and value > 0 then return value end
        return nil
    end

    function Spell.projectile_speed(ability)
        if not Util.valid(ability) then return nil end
        local speed = positive(pcall(function() return ability:get_vdata().m_WeaponInfo.m_flBulletSpeed end))
            or positive(pcall(function() return ability:get_vdata().m_projectileInfo.m_flSpeed end))
        if speed then return speed end
        for _, name in ipairs(SPEED_PROPERTIES) do
            speed = positive(true, Util.method(ability, "get_scaled_property", nil, name))
            if speed then return speed end
        end
        local property = Util.method(ability, "get_property", nil, "ProjectileSpeed")
        if property and type(property) ~= "number" then
            return positive(true, Util.field(property, "m_flSpeed", nil))
                or positive(true, Util.field(property, "m_flProjectileSpeed", nil))
        end
        return nil
    end

    local CAST_DELAY_PROPERTIES = { "AbilityCastDelay", "CastDelay", "m_flCastDelay" }
    local RADIUS_PROPERTIES = { "Radius", "AoERadius", "ExplodeRadius", "ImpactRadius", "AbilityRadius" }

    local function first_property(ability, names)
        for _, name in ipairs(names) do
            local value = positive(true, Util.method(ability, "get_scaled_property", nil, name))
            if value then return value end
        end
        return nil
    end

    function Spell.cast_delay(ability)
        if not Util.valid(ability) then return nil end
        return first_property(ability, CAST_DELAY_PROPERTIES)
    end

    function Spell.aoe_radius(ability)
        if not Util.valid(ability) then return nil end
        return first_property(ability, RADIUS_PROPERTIES)
    end
end

do
    local tracks = {}

    function Track.velocity(entity)
        if not entity or not entity:valid() then
            return Vector(0, 0, 0), Vector(0, 0, 0)
        end

        local now = global_vars.curtime()
        local handle = entity:get_handle()
        local origin = entity:get_origin()
        local data = tracks[handle]
        if not data or now - data.time > K.TRACK_WINDOW then
            data = {
                time = now,
                velocity = Vector(0, 0, 0),
                acceleration = Vector(0, 0, 0),
                samples = { { pos = origin, time = now } },
                directions = {},
            }
            tracks[handle] = data
            return data.velocity, data.acceleration
        end

        local delta_time = now - data.time
        if delta_time <= 0.001 then
            return data.velocity, data.acceleration
        end

        local samples = data.samples
        samples[#samples + 1] = { pos = origin, time = now }
        while #samples > K.TRACK_HISTORY do
            table.remove(samples, 1)
        end

        local velocity = Vector(0, 0, 0)
        local latest = nil
        local total_weight = 0
        for i = 2, #samples do
            local previous, current = samples[i - 1], samples[i]
            local step = current.time - previous.time
            if step > 0.001 then
                local weight = i / #samples
                local sample = (current.pos - previous.pos) / step
                velocity = velocity + sample * weight
                total_weight = total_weight + weight
                latest = sample
            end
        end
        if total_weight > 0 then
            velocity = velocity / total_weight
            if latest then
                velocity = velocity * 0.35 + latest * 0.65
            end
        end

        if latest then
            local speed = math.sqrt(latest.x * latest.x + latest.y * latest.y)
            local directions = data.directions
            if speed > K.TRACK_MOVING_SPEED then
                directions[#directions + 1] = { x = latest.x / speed, y = latest.y / speed, time = now }
            end
            while directions[1] and now - directions[1].time > K.TRACK_DIRECTION_WINDOW do
                table.remove(directions, 1)
            end
        end

        local smoothed_velocity = data.velocity + (velocity - data.velocity) * K.VELOCITY_SMOOTHING
        local acceleration = (smoothed_velocity - data.velocity) / delta_time
        data.acceleration = data.acceleration + (acceleration - data.acceleration) * K.ACCEL_SMOOTHING
        data.velocity = smoothed_velocity
        data.time = now
        return data.velocity, data.acceleration
    end

    function Track.consistency(entity)
        local data = tracks[entity:get_handle()]
        local directions = data and data.directions
        if not directions or #directions < 3 then return 1.0 end
        local sx, sy = 0.0, 0.0
        for _, dir in ipairs(directions) do
            sx, sy = sx + dir.x, sy + dir.y
        end
        return math.sqrt(sx * sx + sy * sy) / #directions
    end

    function Track.cleanup(now)
        for handle, data in pairs(tracks) do
            if now - data.time > K.TRACK_STALE then
                tracks[handle] = nil
            end
        end
    end
end

do
    World.pawn = nil
    World.allies = {}
    World.enemies = {}
    World.troopers = {}
    World.is_rem = false
    local next_refresh = 0.0

    function World.refresh(now)
        if now < next_refresh then return end
        next_refresh = now + K.WORLD_REFRESH

        local pawn = entity_list.local_pawn()
        if not pawn or not pawn:valid() then
            World.pawn = nil
            World.is_rem = false
            return
        end

        local allies, enemies = {}, {}
        local own_handle = pawn:get_handle()
        local team = pawn.m_iTeamNum
        for _, player in pairs(entity_list.by_class_name("C_CitadelPlayerPawn") or {}) do
            if player and player:valid() and player:is_alive() then
                if player.m_iTeamNum ~= team then
                    enemies[#enemies + 1] = player
                elseif player:get_handle() ~= own_handle then
                    allies[#allies + 1] = player
                end
            end
        end

        local name = pawn:get_name()
        World.pawn = pawn
        World.allies = allies
        World.enemies = enemies
        World.troopers = entity_list.by_class_name("C_NPC_Trooper") or {}
        World.is_rem = name ~= nil and string.find(string.lower(name), "familiar", 1, true) ~= nil

        Track.cleanup(now)
        Helpers.cleanup(now)
        Items.cleanup(now)
    end
end

do
    local trace_target = nil
    local function hit_filter(ent)
        return trace_target ~= nil and ent == trace_target
    end
    local function trace_hit(from, to)
        return trace.line(from, to, 0x1, 0, 0, 0, 0, hit_filter)
    end

    function Aim.can_hit(source, position, target)
        if not source or not position then return false, 1.0 end
        trace_target = target
        local ok, result = pcall(trace_hit, source, position)
        trace_target = nil
        if ok and result then
            return result.fraction > 0.95, result.fraction
        end
        return false, 1.0
    end

    local NUDGE_OFFSETS = { { 0, 0, 20 }, { 0, 0, 40 }, { 20, 0, 0 }, { -20, 0, 0 }, { 0, 20, 0 }, { 0, -20, 0 } }

    function Aim.nudge(target, source, position)
        for _, offset in ipairs(NUDGE_OFFSETS) do
            local test = Vector(position.x + offset[1], position.y + offset[2], position.z + offset[3])
            if Aim.can_hit(source, test, target) then return test end
        end
        return position
    end

    local function never_hit() return false end
    local function trace_world(from, to)
        return trace.line(from, to, 0x1C1003, 0, 0, 7, 4, never_hit)
    end

    local function floor_below(origin)
        local ok, result = pcall(trace_world, origin, Vector(origin.x, origin.y, origin.z - K.S1_FLOOR_TRACE))
        if not ok or not result then return origin.z - K.S1_FLOOR_TRACE end
        return origin.z - K.S1_FLOOR_TRACE * result.fraction
    end

    local function current_velocity(target)
        local tracked, acceleration = Track.velocity(target)
        local engine = Util.method(target, "get_velocity", nil)
        if engine and engine.x * engine.x + engine.y * engine.y > 1 then
            return engine, acceleration
        end
        return tracked, acceleration
    end

    local motion = { handle = nil, time = nil, model = nil }

    function Aim.motion(target, now)
        local handle = target:get_handle()
        if motion.handle == handle and motion.time == now then
            return motion.model
        end

        local origin = target:get_origin()
        local base = target:get_bone_pos(K.S1_AIM_BONE) or origin
        if not origin or not base then return nil end

        local velocity, acceleration = current_velocity(target)
        local ax, ay = acceleration.x, acceleration.y
        local accel = math.sqrt(ax * ax + ay * ay)
        if accel < K.S1_ACCEL_THRESHOLD then
            ax, ay = 0.0, 0.0
        elseif accel > K.S1_MAX_ACCEL then
            ax, ay = ax * K.S1_MAX_ACCEL / accel, ay * K.S1_MAX_ACCEL / accel
        end

        local consistency = Track.consistency(target)
        local airborne = not Unit.on_ground(target)
        local model = {
            origin = origin,
            base = base,
            vx = velocity.x,
            vy = velocity.y,
            vz = airborne and velocity.z or 0.0,
            ax = ax,
            ay = ay,
            speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y),
            consistency = consistency,
            lead_scale = K.S1_MIN_LEAD_SCALE + (1 - K.S1_MIN_LEAD_SCALE) * consistency,
            airborne = airborne,
            floor_z = airborne and floor_below(origin) or origin.z,
            latency = Util.latency(),
        }
        motion.handle, motion.time, motion.model = handle, now, model
        return model
    end

    local function position_at(m, t)
        local horizon = math.min(t, K.S1_ACCEL_HORIZON)
        local accel_term = horizon * (t - 0.5 * horizon)
        local x = m.base.x + (m.vx * t + m.ax * accel_term) * m.lead_scale
        local y = m.base.y + (m.vy * t + m.ay * accel_term) * m.lead_scale
        local z = m.base.z
        if m.airborne then
            local feet = m.origin.z + m.vz * t - 0.5 * K.S1_GRAVITY * t * t
            z = math.max(feet, m.floor_z) + (m.base.z - m.origin.z)
        end
        return Vector(x, y, z)
    end

    local function intercept_time(m, source, speed, delay)
        local start = position_at(m, delay)
        local vx, vy = m.vx * m.lead_scale, m.vy * m.lead_scale
        local dx, dy, dz = start.x - source.x, start.y - source.y, start.z - source.z
        local a = vx * vx + vy * vy - speed * speed
        local b = 2 * (dx * vx + dy * vy)
        local c = dx * dx + dy * dy + dz * dz
        if math.abs(a) > 1e-6 then
            local discriminant = b * b - 4 * a * c
            if discriminant >= 0 then
                local root = math.sqrt(discriminant)
                local t1, t2 = (-b - root) / (2 * a), (-b + root) / (2 * a)
                local t = math.huge
                if t1 > 0 then t = t1 end
                if t2 > 0 and t2 < t then t = t2 end
                if t < math.huge then return t end
            end
        elseif b < 0 then
            return -c / b
        end
        return math.sqrt(c) / speed
    end

    function Aim.predict(target, source, shot, now)
        if not target or not target:valid() or not source then return nil end
        local m = Aim.motion(target, now)
        if not m then return nil end

        local speed = math.max(shot.speed, 1)
        local delay = shot.delay + m.latency
        local flight = intercept_time(m, source, speed, delay)
        local position = nil
        for _ = 1, K.S1_REFINE_STEPS do
            position = position_at(m, math.min(delay + flight, K.S1_MAX_LEAD_TIME))
            local next_flight = source:Distance(position) / speed
            local converged = math.abs(next_flight - flight) < 0.001
            flight = next_flight
            if converged then break end
        end
        return position, m.base, math.min(delay + flight, K.S1_MAX_LEAD_TIME)
    end

    function Aim.from(target, shot, source)
        return (Aim.predict(target, source, shot, global_vars.curtime()))
    end

    function Aim.hit_chance(target, shot, lead_time, now)
        local m = Aim.motion(target, now)
        if not m then return 0.0 end
        local strafe = (1 - m.consistency) * math.min(m.speed * lead_time, K.S1_MAX_STRAFE_SPREAD)
        local air = m.airborne and math.min(math.abs(m.vz) * lead_time * 0.25, K.S1_MAX_AIR_SPREAD) or 0.0
        local tolerance = K.S1_TARGET_RADIUS + (shot.radius or 0.0)
        return tolerance / (tolerance + strafe + air)
    end

    local BONE_PRIORITIES = {
        { 90, { "spine" } },
        { 80, { "pelvis", "hip" } },
        { 70, { "neck", "clavicle" } },
        { 60, { "thigh", "upperarm" } },
    }
    local bones_by_model = {}

    local function build_bones(target)
        local points = {}
        for bone_name in pairs(target:get_bones() or {}) do
            local lower = string.lower(bone_name)
            if not lower:find("head", 1, true) and not lower:find("eye", 1, true) then
                local priority = 40
                for _, rule in ipairs(BONE_PRIORITIES) do
                    if Util.has_any(lower, rule[2]) then
                        priority = rule[1]
                        break
                    end
                end
                points[#points + 1] = {
                    bone = bone_name,
                    priority = priority,
                    is_body = bone_name:find("spine", 1, true) ~= nil or bone_name:find("pelvis", 1, true) ~= nil,
                }
            end
        end
        table.sort(points, function(a, b) return a.priority > b.priority end)
        for i = #points, K.S1_MAX_AIM_BONES + 1, -1 do
            points[i] = nil
        end
        return points
    end

    function Aim.bones(target)
        local model = Util.method(target, "get_model_name", "")
        local points = bones_by_model[model]
        if points then return points end
        points = build_bones(target)
        if model ~= "" and #points > 0 then
            bones_by_model[model] = points
        end
        return points
    end

    local function body_bonus(target)
        local speed = Track.velocity(target):Length2D()
        local bonus = speed < 200 and 10 or speed < 400 and 30 or 50
        if not Unit.on_ground(target) then bonus = bonus + 20 end
        return bonus
    end

    function Aim.best_point(target, source, shot, now)
        if not target or not target:valid() then return nil end
        local points = Aim.bones(target)
        if #points == 0 then return nil end

        local predicted, base, lead_time = Aim.predict(target, source, shot, now)
        if not predicted then return nil end
        local shift = predicted - base

        local bonus = body_bonus(target)
        local camera_angles = utils.get_camera_angles()
        local best, best_score = nil, -math.huge
        for _, point in ipairs(points) do
            local bone = target:get_bone_pos(point.bone)
            if bone then
                local position = bone + shift
                local hit, fraction = Aim.can_hit(source, position, target)
                local score = point.priority
                if point.is_body then score = score + bonus end
                if hit then
                    score = score + 120
                else
                    score = score - 15
                    if fraction > 0.85 then score = score + 25 end
                end
                score = score - utils.get_fov(camera_angles, utils.calc_angle(source, position)) * 0.5
                if score > best_score then
                    best, best_score = position, score
                end
            end
        end
        return best or Aim.nudge(target, source, predicted), lead_time
    end

    local function target_score(enemy, distance, fov)
        local score = (1.0 - Unit.hp(enemy)) * 200
        if Unit.has_state(enemy, STATE.STUNNED) then score = score + 100 end
        if Unit.has_state(enemy, STATE.ULTING) then score = score + 80 end
        if Unit.has_state(enemy, STATE.SILENCED)
            or Unit.has_state(enemy, EModifierState.MODIFIER_STATE_DISARMED) then
            score = score + 50
        end
        score = score + (1.0 - distance / cfg.s1_range) * 30
        score = score + (1.0 - fov / cfg.s1_fov) * 20
        if not Unit.on_ground(enemy) then score = score + 30 end
        return score
    end

    function Aim.pick_target(pawn, enemies)
        local my_origin = pawn:get_origin()
        if not my_origin then return nil end
        local camera_pos = utils.get_camera_pos()
        local camera_angles = utils.get_camera_angles()
        local best, best_score = nil, -math.huge
        for _, enemy in ipairs(enemies) do
            if enemy:valid() and enemy:is_alive() and (cfg.s1_bending or enemy:is_visible()) then
                local origin = enemy:get_origin()
                local distance = origin and my_origin:Distance(origin) or math.huge
                if distance <= cfg.s1_range then
                    local fov = utils.get_fov(camera_angles, utils.calc_angle(camera_pos, origin))
                    if fov <= cfg.s1_fov and not (cfg.s1_skip_parry and Unit.has_any_state(enemy, STATE.WASTED)) then
                        local score = target_score(enemy, distance, fov)
                        if score > best_score then
                            best, best_score = enemy, score
                        end
                    end
                end
            end
        end
        return best
    end

    function Aim.smooth(cmd, position, smooth, psilent_fov)
        local angle = utils.calc_angle(utils.get_camera_pos(), position)
        if smooth > 1 then
            cmd:smooth_aim(angle, smooth)
        else
            cmd.viewangles = angle
            utils.set_camera_angles(angle)
        end
        if utils.get_fov(utils.get_camera_angles(), angle) <= psilent_fov then
            cmd:set_psilent_at_pos(position)
        end
    end
end

do
    local bullet = {
        anchor = nil,
        stale = nil,
        stale_ticks = 0,
        search_index = 0,
        retry_at = 0.0,
        target = 0,
        traces = 0,
    }

    local SEARCH_DIRECTIONS = {
        { 0, 0, 1 }, { 1, 1, 0 }, { -1, 1, 0 }, { 1, 0, 1 }, { -1, 0, 1 }, { 0, 1, 1 },
        { 1, 1, 1 }, { -1, 1, 1 }, { 0, -1, 0 }, { 1, -1, 0 }, { -1, -1, 0 },
        { 0, -1, 1 }, { 1, -1, 1 }, { -1, -1, 1 },
    }
    for _, d in ipairs(SEARCH_DIRECTIONS) do
        local n = math.sqrt(d[1] * d[1] + d[2] * d[2])
        if n > 0 then d[1], d[2] = d[1] / n, d[2] / n end
    end

    local RING_DIRECTIONS = {
        { 1, 0 }, { -1, 0 }, { 0, 1 },
        { 0.70710678, 0.70710678 }, { -0.70710678, 0.70710678 },
        { 0.70710678, -0.70710678 }, { -0.70710678, -0.70710678 },
        { 0, -1 },
    }
    local RING_SLOTS = #RING_DIRECTIONS * K.BULLET_SEARCH_RINGS

    local function length(v)
        return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    end

    local function never_hit() return false end

    local function trace_fraction(from, to)
        bullet.traces = bullet.traces + 1
        return trace.line(from, to, 0x1C1003, 0, 0, 7, 4, never_hit).fraction
    end

    local function is_clear(from, to)
        return trace_fraction(from, to) > 0.985
    end

    local function has_clearance(from, to)
        local path = to - from
        local distance = length(path)
        if distance < 1 then return true end
        local forward = path * (1 / distance)
        local rx, ry = forward.y, -forward.x
        local rlen = math.sqrt(rx * rx + ry * ry)
        local right = rlen > 0.001 and Vector(rx / rlen * 18, ry / rlen * 18, 0) or Vector(18, 0, 0)
        local up = Vector(0, 0, 18)
        for i = 1, 3 do
            local p = from + path * (i * 0.25)
            if trace_fraction(p, p + up) < 0.99 then return false end
            if trace_fraction(p, p - up) < 0.99 then return false end
            if trace_fraction(p, p + right) < 0.99 then return false end
            if trace_fraction(p, p - right) < 0.99 then return false end
        end
        return true
    end

    local function search_basis(base, aim)
        local forward = aim - base
        local distance = length(forward)
        if distance < 1 then return nil end
        forward = forward * (1 / distance)
        local h = math.sqrt(forward.x * forward.x + forward.y * forward.y)
        if h < 0.001 then return nil end
        return forward, Vector(forward.y / h, -forward.x / h, 0), Vector(0, 0, 1)
    end

    local function candidate_offset(index, right, up, forward, step, max_offset, max_forward)
        local radius, rx, uy, fz
        if index < RING_SLOTS then
            radius = step * (math.floor(index / #RING_DIRECTIONS) + 1)
            local dir = RING_DIRECTIONS[(index % #RING_DIRECTIONS) + 1]
            rx, uy, fz = dir[1], dir[2], 0
        else
            local i = index - RING_SLOTS
            local ring = math.floor(i / #SEARCH_DIRECTIONS)
            if ring >= K.BULLET_SEARCH_RINGS then return nil, false end
            radius = step * (ring + 1)
            local dir = SEARCH_DIRECTIONS[(i % #SEARCH_DIRECTIONS) + 1]
            rx, uy, fz = dir[1], dir[2], dir[3]
        end
        if rx == 0 and uy == 0 and radius > max_forward then return nil, true end
        local offset = Vector(0, 0, 0)
        if rx ~= 0 then offset = offset + right * (rx * radius) end
        if uy ~= 0 then offset = offset + up * (uy * (uy > 0 and 96 or 40) * radius / max_offset) end
        if fz ~= 0 and max_forward > 0 then offset = offset + forward * math.min(radius, max_forward) end
        if offset.z > 96 then
            offset = Vector(offset.x, offset.y, 96)
        elseif offset.z < -40 then
            offset = Vector(offset.x, offset.y, -40)
        end
        return offset, false
    end

    local function try_candidate(base, offset, target, shot)
        local candidate = base + offset
        local fraction = trace_fraction(base, candidate)
        if fraction < 0.999 then
            local distance = length(offset)
            local usable = math.max(fraction - (distance > 0 and math.max(0.05, 15 / distance) or 0.05), 0)
            if usable <= 0.05 then return nil end
            offset = offset * usable
            candidate = base + offset
        end
        local aim = Aim.from(target, shot, candidate)
        if aim and is_clear(candidate, aim) and has_clearance(candidate, aim) then
            return offset
        end
        return nil
    end

    local function try_rescale(base, offset, target, shot, scale)
        if bullet.traces >= K.BULLET_TRACE_BUDGET then return nil end
        local scaled = offset * scale
        local candidate = base + scaled
        if trace_fraction(base, candidate) <= 0.95 then return nil end
        local aim = Aim.from(target, shot, candidate)
        if aim and is_clear(candidate, aim) then return scaled end
        return nil
    end

    local function reset_search()
        bullet.anchor = nil
        bullet.search_index = 0
        bullet.retry_at = 0.0
    end

    local function remember(offset)
        bullet.stale = offset
        bullet.stale_ticks = K.BULLET_STALE_TICKS
    end

    local function reuse_anchor(base, target, shot, max_offset, aim)
        if not bullet.anchor or length(bullet.anchor) > max_offset * 1.25 then return nil end
        local position = base + bullet.anchor
        local anchor_aim = Aim.from(target, shot, position) or aim
        if is_clear(base, position) and is_clear(position, anchor_aim) then
            remember(bullet.anchor)
            return position
        end
        return nil
    end

    local function correct_anchor(base, target, shot)
        local anchor = bullet.anchor
        local corrected = try_rescale(base, anchor, target, shot, 0.9)
            or try_rescale(base, anchor, target, shot, 1.1)
            or try_rescale(base, anchor, target, shot, 0.8)
        remember(corrected or anchor)
        bullet.anchor = corrected
        if corrected then return base + corrected end
        bullet.search_index = 0
        return nil
    end

    local function search(base, target, shot, max_offset, aim, now)
        local forward, right, up = search_basis(base, aim)
        if not forward then return nil end
        local step = max_offset / K.BULLET_SEARCH_RINGS
        local max_forward = max_offset * 0.7
        while bullet.traces < K.BULLET_TRACE_BUDGET do
            local offset, skip = candidate_offset(bullet.search_index, right, up, forward, step, max_offset, max_forward)
            bullet.search_index = bullet.search_index + 1
            if offset then
                local found = try_candidate(base, offset, target, shot)
                if found then
                    bullet.anchor = found
                    remember(found)
                    return base + found
                end
            elseif not skip then
                bullet.search_index = 0
                bullet.retry_at = now + K.BULLET_RETRY_DELAY
                return nil
            end
        end
        return nil
    end

    local function reuse_stale(base)
        if not bullet.stale or bullet.stale_ticks <= 0 then return nil end
        local position = base + bullet.stale
        if is_clear(base, position) then
            bullet.stale_ticks = bullet.stale_ticks - 1
            return position
        end
        bullet.stale_ticks = 0
        return nil
    end

    function Bullet.find_source(base, target, shot, max_offset, aim, now)
        if not target or not target:valid() or not aim then return nil, false end
        local key = target:get_handle()
        if key ~= bullet.target then
            bullet.target = key
            reset_search()
        end
        bullet.traces = 0

        if is_clear(base, aim) then
            reset_search()
            return base, false
        end

        local position = reuse_anchor(base, target, shot, max_offset, aim)
        if not position and bullet.anchor then
            position = correct_anchor(base, target, shot)
        end
        if not position and not bullet.anchor and now >= bullet.retry_at then
            position = search(base, target, shot, max_offset, aim, now)
        end
        position = position or reuse_stale(base)
        if position then return position, true end
        return nil, false
    end
end

do
    local s1 = {
        casting = false,
        target = nil,
        aim = nil,
        source = nil,
        bent = false,
        cast_time = 0.0,
        shot = { speed = K.S1_DEFAULT_SPEED, delay = 0.0, radius = 0.0 },
        shot_handle = nil,
        shot_time = -math.huge,
    }

    function Skill1.reset()
        s1.casting = false
        s1.target = nil
        s1.aim = nil
        s1.source = nil
        s1.bent = false
        s1.members = nil
        s1.cluster = false
    end

    function Skill1.is_casting()
        return s1.casting
    end

    function Skill1.target()
        if s1.casting then return s1.target end
        return s1.candidate
    end

    function Skill1.members()
        if s1.casting then return s1.members end
        return s1.preview
    end

    local function feet_prediction(enemy, source, shot, now)
        local predicted, base = Aim.predict(enemy, source, shot, now)
        local origin = enemy:get_origin()
        if not predicted or not base or not origin then return nil end
        return Vector(predicted.x, predicted.y, predicted.z - (base.z - origin.z))
    end

    local function cluster_aim(cmd, pawn, enemies, shot, now)
        if not cfg.s1_multi then return nil end
        local own = pawn:get_origin()
        if not own then return nil end
        local source = cmd.orig_vec_camera_position or cmd.vec_camera_position or utils.get_camera_pos()
        local camera_angles = utils.get_camera_angles()
        local radius = (shot.radius and shot.radius > 0) and shot.radius or cfg.s1_multi_radius
        local reach = radius * 0.85

        local points = {}
        for _, enemy in ipairs(enemies) do
            if Util.valid(enemy) and enemy:is_alive() and enemy:is_visible()
                and not (cfg.s1_skip_parry and Unit.has_any_state(enemy, STATE.WASTED)) then
                local origin = enemy:get_origin()
                if origin and own:Distance(origin) <= cfg.s1_range
                    and utils.get_fov(camera_angles, utils.calc_angle(source, origin)) <= cfg.s1_fov + 15 then
                    local feet = feet_prediction(enemy, source, shot, now)
                    if feet then points[#points + 1] = { unit = enemy, feet = feet, hp = Unit.hp(enemy) } end
                end
            end
        end
        if #points < cfg.s1_multi_min then return nil end

        local candidates = {}
        local cx, cy, cz = 0, 0, 0
        for i, a in ipairs(points) do
            candidates[#candidates + 1] = a.feet
            cx, cy, cz = cx + a.feet.x, cy + a.feet.y, cz + a.feet.z
            for j = i + 1, #points do
                local b = points[j]
                candidates[#candidates + 1] = Vector((a.feet.x + b.feet.x) * 0.5, (a.feet.y + b.feet.y) * 0.5, math.min(a.feet.z, b.feet.z))
            end
        end
        candidates[#candidates + 1] = Vector(cx / #points, cy / #points, cz / #points)

        local best, best_members, best_score = nil, nil, -math.huge
        for _, point in ipairs(candidates) do
            local members, hp_sum = {}, 0
            for _, p in ipairs(points) do
                local dx, dy = p.feet.x - point.x, p.feet.y - point.y
                if dx * dx + dy * dy <= reach * reach and math.abs(p.feet.z - point.z) < 120 then
                    members[#members + 1] = p.unit
                    hp_sum = hp_sum + p.hp
                end
            end
            if #members >= cfg.s1_multi_min then
                local aim = Vector(point.x, point.y, point.z + 8)
                local score = #members * 100 - hp_sum * 15 - utils.get_fov(camera_angles, utils.calc_angle(source, aim)) * 0.5
                if score > best_score and Aim.can_hit(source, aim, nil) then
                    best, best_members, best_score = aim, members, score
                end
            end
        end
        if not best then return nil end

        local primary, primary_fov = nil, math.huge
        for _, unit in ipairs(best_members) do
            local origin = unit:get_origin()
            local fov = origin and utils.get_fov(camera_angles, utils.calc_angle(source, origin)) or math.huge
            if fov < primary_fov then primary, primary_fov = unit, fov end
        end
        return best, primary, best_members, source
    end

    local function read_shot(ability, now)
        local handle = Util.handle(ability)
        if handle == s1.shot_handle and now - s1.shot_time < K.S1_SPEED_REFRESH then
            return s1.shot
        end
        local speed = Spell.projectile_speed(ability)
        s1.shot = {
            speed = speed and speed >= K.S1_MIN_SPEED and speed <= K.S1_MAX_SPEED and speed or K.S1_DEFAULT_SPEED,
            delay = Spell.cast_delay(ability) or 0.0,
            radius = Spell.aoe_radius(ability) or 0.0,
        }
        s1.shot_handle = handle
        s1.shot_time = now
        return s1.shot
    end

    local function remaining_shot(shot, now)
        return {
            speed = shot.speed,
            delay = math.max(0.0, shot.delay - (now - s1.cast_time)),
            radius = shot.radius,
        }
    end

    local function compute_shot(cmd, target, shot, now, wall_fallback)
        local source = cmd.orig_vec_camera_position or cmd.vec_camera_position or utils.get_camera_pos()
        local aim, lead_time = Aim.best_point(target, source, shot, now)
        if not aim then return nil end

        if not cfg.s1_bending then
            if not Aim.can_hit(source, aim, target) then
                aim = Aim.nudge(target, source, aim)
            end
            return aim, source, false, lead_time
        end

        local bent_source, bent = Bullet.find_source(source, target, shot, cfg.s1_bend_range, aim, now)
        if bent then
            local bent_aim, _, bent_time = Aim.predict(target, bent_source, shot, now)
            return bent_aim or aim, bent_source, true, bent_time or lead_time
        end
        if not bent_source and wall_fallback and not Aim.can_hit(source, aim, target) then
            aim = Aim.nudge(target, source, aim)
        end
        return aim, source, false, lead_time
    end

    local function hit_chance(target, aim, source, bent, shot, lead_time, now)
        if not bent and not Aim.can_hit(source, aim, target) then return 0.0 end
        return Aim.hit_chance(target, shot, lead_time or 0.0, now)
    end

    local function is_targetable(target)
        return target and target:valid() and target:is_alive()
            and (cfg.s1_bending or target:is_visible())
    end

    local function try_lock(cmd, pawn, enemies, shot, now)
        local group_aim, primary, members, group_source = cluster_aim(cmd, pawn, enemies, shot, now)
        if group_aim then
            if not Util.face(cmd, group_aim, K.TURN_SPEED) then return false end
            s1.casting, s1.target, s1.aim, s1.source, s1.bent = true, primary, group_aim, group_source, false
            s1.members, s1.cluster, s1.cast_time = members, true, now
            cmd.execute_ability_indices = cmd.execute_ability_indices | (1 << EAbilitySlots_t.ESlot_Signature_1)
            cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY1)
            Events.emit("pillow", primary, #members)
            return true
        end

        local target = Aim.pick_target(pawn, enemies)
        if not is_targetable(target) then return false end

        local aim, source, bent, lead_time = compute_shot(cmd, target, shot, now, true)
        if not aim then return false end
        if bent then cmd.vec_camera_position = source end
        if hit_chance(target, aim, source, bent, shot, lead_time, now) < cfg.s1_hitchance then return false end
        if not Util.face(cmd, aim, K.TURN_SPEED) then return false end

        s1.casting = true
        s1.target = target
        s1.aim = aim
        s1.source = source
        s1.bent = bent
        s1.cast_time = now
        s1.members, s1.cluster = nil, false
        cmd.execute_ability_indices = cmd.execute_ability_indices | (1 << EAbilitySlots_t.ESlot_Signature_1)
        cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY1)
        return true
    end

    local function steer(cmd, shot, now, just_locked)
        local target = s1.target
        local confirmed = just_locked
        if s1.cluster and not just_locked then
            local group_aim, primary, members, group_source = cluster_aim(cmd, World.pawn, World.enemies, remaining_shot(shot, now), now)
            if group_aim then
                s1.aim, s1.target, s1.members, s1.source = group_aim, primary, members, group_source
                confirmed = true
            end
        end
        if not confirmed and not just_locked then
            local aim, source, bent = compute_shot(cmd, target, remaining_shot(shot, now), now, false)
            s1.aim, s1.source, s1.bent = aim, source, bent
            if not aim then return end
            if bent then cmd.vec_camera_position = source end
            confirmed = bent or Aim.can_hit(source, aim, target)
        end
        if not confirmed or (not s1.cluster and Unit.fov_to(s1.aim) > cfg.s1_fov) then return end

        Util.face(cmd, s1.aim, K.TURN_SPEED_FAST)
    end

    function Skill1.run(cmd, pawn, enemies, now)
        local ability = Spell.by_slot(pawn, EAbilitySlots_t.ESlot_Signature_1)
        if not ability or not ability:valid() or not cfg.s1_key then
            Skill1.reset()
            s1.candidate = nil
            s1.preview = nil
            return
        end

        local ready = (ability:can_be_executed() or 0) == 0
        if s1.casting and ready then
            Skill1.reset()
        end
        local shot = read_shot(ability, now)
        if not s1.casting then
            local _, primary, members = cluster_aim(cmd, pawn, enemies, shot, now)
            s1.preview = members
            s1.candidate = primary or Aim.pick_target(pawn, enemies)
        end

        local just_locked = not s1.casting and ready and try_lock(cmd, pawn, enemies, shot, now)

        if not s1.casting then return end
        if not is_targetable(s1.target) then
            Skill1.reset()
            return
        end
        steer(cmd, shot, now, just_locked)
    end
end

do
    local h = {
        healed = {},
        visited = {},
        was_ready = true,
        not_ready_since = 0.0,
        hold_until = 0.0,
        active_until = 0.0,
        force_until = 0.0,
        was_attached = false,
        was_auto = false,
        self_cycle = false,
        casted_at = -1.0,
    }

    local function mark_healed(ally)
        if ally and ally:valid() then
            h.healed[ally:get_handle()] = global_vars.curtime()
        end
    end

    local function is_healed(ally)
        return h.healed[ally:get_handle()] ~= nil
    end

    function Heal.expire(now)
        for handle, timestamp in pairs(h.healed) do
            if now - timestamp > K.HEAL_CHAIN_EXPIRE then
                h.healed[handle] = nil
            end
        end
    end

    function Heal.track_chain(pawn, now)
        local ready = Spell.ready(Spell.attach(pawn))
        if not ready and h.was_ready then
            h.not_ready_since = now
        end
        if ready and not h.was_ready and now - h.not_ready_since > K.HEAL_CHAIN_RESET then
            local had_chain = next(h.healed) ~= nil
            h.healed = {}
            h.visited = {}
            if had_chain then Events.emit("chain") end
        end
        h.was_ready = ready
    end

    local function self_needs_heal(pawn)
        local max_health = pawn.m_iMaxHealth
        if not max_health or max_health <= 0 then
            max_health = pawn:get_max_health()
        end
        local health = pawn.m_iHealth
        if not health or not max_health or max_health <= 0 then return false end
        return health / max_health <= cfg.s2_self_hp
    end

    local function ally_needs_heal(pawn)
        local origin = pawn:get_origin()
        if not origin then return false end
        for _, ally in ipairs(World.allies) do
            if ally:valid() and ally:is_alive()
                and not Unit.has_any_state(ally, STATE.PROTECTED)
                and not (cfg.s2_chain and is_healed(ally)) then
                local ally_origin = ally:get_origin()
                if ally_origin
                    and origin:Distance(ally_origin) <= cfg.s2_ally_range
                    and Unit.hp(ally) <= cfg.s2_ally_hp then
                    return true
                end
            end
        end
        return false
    end

    local function cast_range(pawn)
        local ability = Spell.attach(pawn)
        local range = ability and ability:get_scaled_property("AbilityCastRange")
        if type(range) == "number" and range > 0 then return range end
        return cfg.s2_ally_range
    end

    local function collect(pool, is_ally, ctx, out)
        for _, unit in ipairs(pool) do
            if unit:valid() and unit:is_alive() and (not is_ally or not Unit.has_any_state(unit, STATE.PROTECTED)) then
                local distance = ctx.origin:Distance(unit:get_origin())
                if is_ally or distance <= ctx.range then
                    local handle = unit:get_handle()
                    if handle ~= ctx.own_handle then
                        if unit:has_modifier(MOD.HOST) then
                            h.healed[handle] = ctx.now
                        elseif not (is_ally and cfg.s2_chain and is_healed(unit))
                            and not (ctx.is_auto and h.visited[handle] and not h.self_cycle)
                            and distance <= ctx.range then
                            local hp = Unit.hp(unit)
                            if hp <= ctx.threshold then
                                out[#out + 1] = { unit = unit, is_ally = is_ally, hp = hp, distance = distance }
                            end
                        end
                    end
                end
            end
        end
    end

    local function by_distance(a, b) return a.distance < b.distance end
    local function by_hp(a, b) return a.hp < b.hp end

    local function find_target(pawn, is_auto, attached, now)
        local my_hp = Unit.hp(pawn)
        local self_needs = my_hp <= cfg.s2_self_hp
        local keep_needs = cfg.s2_keep_heal
            and my_hp < cfg.s2_keep_hp
            and (h.self_cycle or attached or now < h.active_until)
        local healing_self = self_needs or keep_needs

        local ctx = {
            origin = pawn:get_origin(),
            own_handle = pawn:get_handle(),
            range = cast_range(pawn),
            now = now,
            is_auto = is_auto,
            threshold = healing_self and 1.0 or (attached and K.HEAL_ATTACHED_ALLY_HP or cfg.s2_ally_hp),
        }

        local candidates = {}
        collect(World.allies, true, ctx, candidates)
        if healing_self then
            collect(World.troopers, false, ctx, candidates)
        end
        if #candidates == 0 then return nil, false end

        local closest_first = healing_self or cfg.s2_closest_first
        table.sort(candidates, closest_first and by_distance or by_hp)
        return candidates[1].unit, candidates[1].is_ally
    end

    local function clear_alt_cast(cmd)
        cmd:clear_buttonstate1(K.IN_ALT_CAST)
        cmd:clear_buttonstate2(K.IN_ALT_CAST)
        pcall(function() cmd:clear_buttonstate3(K.IN_ALT_CAST) end)
        if cmd.set_input then pcall(function() cmd:set_input(K.IN_ALT_CAST, 0) end) end
    end

    function Heal.hold_alt_cast(cmd)
        cmd:add_buttonstate1(K.IN_ALT_CAST)
        cmd:add_buttonstate2(K.IN_ALT_CAST)
        pcall(function() cmd:add_buttonstate3(K.IN_ALT_CAST) end)
        if cmd.set_input then pcall(function() cmd:set_input(K.IN_ALT_CAST, 1) end) end
    end

    local function aim_point(target, is_ally)
        local position = not is_ally and Unit.bone(target, "spine_2", "spine_0") or nil
        if position then return position end
        local origin = target:get_origin()
        return origin and Vector(origin.x, origin.y, origin.z + K.HEAL_AIM_HEIGHT) or nil
    end

    local function update_cycle(pawn, now, attached, moving)
        if attached and not h.was_attached then
            h.hold_until = 0.0
            Events.emit("attach", Heal.host(pawn))
        end
        h.was_attached = attached

        local self_needs = self_needs_heal(pawn)
        if not cfg.s2_keep_heal then
            h.self_cycle = false
        elseif self_needs then
            h.self_cycle = true
        elseif h.self_cycle and Unit.hp(pawn) >= cfg.s2_keep_hp then
            h.self_cycle = false
            h.visited = {}
        end

        if attached or moving then
            h.active_until = now + K.HEAL_CAST_HOLD
        elseif now > h.active_until then
            h.visited = {}
        end

        if cfg.s2_auto and not h.was_auto and cfg.s2_force_next then
            h.force_until = now + K.HEAL_FORCE_WINDOW
        end
        h.was_auto = cfg.s2_auto
        return self_needs
    end

    local function is_blocked(pawn, now, moving)
        if now < h.hold_until or moving then return true end
        if now > h.force_until and pawn:has_modifier(MOD.ATTACH_HEAL) then return true end
        return pawn:has_modifier(MOD.LOCKOUT)
    end

    local function cast_auto(cmd, target, is_ally, aim, slot, now, reason)
        if not Util.face(cmd, aim, reason == "panic" and K.TURN_SPEED_FAST or K.TURN_SPEED) then return false end
        if cmd:can_psilent_at_pos(aim) then
            cmd:set_psilent_at_pos(aim)
        else
            cmd.ang_camera_angles = utils.calc_angle(utils.get_camera_pos(), aim)
        end
        cmd.button_state0 = cmd.button_state0 & ~1
        cmd:clear_buttonstate1(1)
        cmd:clear_buttonstate2(1)
        cmd:clear_buttonstate3(1)
        clear_alt_cast(cmd)
        cmd.execute_ability_indices = (cmd.execute_ability_indices or 0) | (1 << slot)

        h.visited[target:get_handle()] = true
        if is_ally then mark_healed(target) end
        h.hold_until = now + K.HEAL_CAST_HOLD
        h.active_until = now + K.HEAL_CAST_HOLD
        h.force_until = 0.0
        h.casted_at = now
        Events.emit("jump", target, reason or is_ally)
        return true
    end

    local function cast_manual(cmd, target, is_ally, aim, slot, now)
        Aim.smooth(cmd, aim, cfg.s2_smooth, cfg.s2_psilent_fov)
        if Unit.fov_to(aim) > K.HEAL_MANUAL_FOV then return end
        cmd:clear_buttonstate1(1)
        clear_alt_cast(cmd)
        cmd.execute_ability_indices = (cmd.execute_ability_indices or 0) | (1 << slot)
        if is_ally then mark_healed(target) end
        h.hold_until = now + K.HEAL_CAST_HOLD
        h.casted_at = now
        Events.emit("jump", target, is_ally)
    end

    local burst = { last = nil, events = {} }

    local function burst_share(pawn, now)
        local health = Util.number(pawn.m_iHealth, 0)
        local max = math.max(1, Util.number(Util.method(pawn, "get_max_health", 1), 1))
        if burst.last and health < burst.last then
            burst.events[#burst.events + 1] = { time = now, amount = burst.last - health }
        end
        burst.last = health
        local total = 0
        for i = #burst.events, 1, -1 do
            if now - burst.events[i].time > 1.0 then
                table.remove(burst.events, i)
            else
                total = total + burst.events[i].amount
            end
        end
        return total / max
    end

    local function enemy_near(origin, radius)
        for _, enemy in ipairs(World.enemies) do
            local enemy_origin = Util.valid(enemy) and enemy:is_alive() and enemy:get_origin()
            if enemy_origin and origin:Distance(enemy_origin) <= radius then return true end
        end
        return false
    end

    local function panic_target(pawn)
        local origin = pawn:get_origin()
        local range = cast_range(pawn)
        local best, best_distance = nil, math.huge
        for _, list in ipairs({ World.allies, World.troopers }) do
            for _, unit in pairs(list) do
                if Util.valid(unit) and unit:is_alive() and not Unit.has_any_state(unit, STATE.PROTECTED) then
                    local unit_origin = unit:get_origin()
                    local distance = unit_origin and origin:Distance(unit_origin) or math.huge
                    if distance <= range and distance < best_distance then
                        best, best_distance = unit, distance
                    end
                end
            end
            if best then return best, list == World.allies end
        end
        return nil, false
    end

    local function try_panic(cmd, pawn, now, attached, moving)
        local share = burst_share(pawn, now)
        if not cfg.s2_panic or attached or moving then return false end
        local origin = pawn:get_origin()
        if not origin or not enemy_near(origin, 35 * K.UNIT_METER) then return false end
        if Unit.hp(pawn) >= cfg.s2_panic_hp and share < cfg.s2_panic_burst then return false end
        if pawn:has_modifier(MOD.LOCKOUT) then return false end

        local ability = Spell.attach(pawn)
        if not Spell.ready(ability) then return false end
        local target, is_ally = panic_target(pawn)
        local aim = target and aim_point(target, is_ally)
        if not aim then return false end
        local slot = ability.m_eAbilitySlot or EAbilitySlots_t.ESlot_Signature_2 or 1
        cast_auto(cmd, target, is_ally, aim, slot, now, "panic")
        return true
    end

    function Heal.run(cmd, pawn, now, attached)
        local moving = pawn:has_modifier(MOD.CAST_DELAY) or pawn:has_modifier(MOD.MOVING)
        local self_needs = update_cycle(pawn, now, attached, moving)
        if not cfg.s2_enable then return end
        if try_panic(cmd, pawn, now, attached, moving) then return end

        local forced = h.force_until > now
        local ally_needs = false
        if not (cfg.s2_key or cfg.s2_auto or forced or self_needs) then
            ally_needs = ally_needs_heal(pawn)
            if not ally_needs and not h.self_cycle then return end
        end

        local ability = Spell.attach(pawn)
        if not Spell.ready(ability) then return end
        local slot = ability.m_eAbilitySlot or EAbilitySlots_t.ESlot_Signature_2 or 1
        if is_blocked(pawn, now, moving) then return end

        local is_auto = (cfg.s2_auto or forced or self_needs or ally_needs) and not cfg.s2_key
        local target, is_ally = find_target(pawn, is_auto, attached, now)
        if not target or not target:valid() or not target:is_alive() then return end

        local aim = aim_point(target, is_ally)
        if not aim then return end
        if is_auto then
            cast_auto(cmd, target, is_ally, aim, slot, now)
        else
            cast_manual(cmd, target, is_ally, aim, slot, now)
        end
    end

    function Heal.casted(now)
        return h.casted_at == now
    end

    -- Jump onto a specific ally (used by the helper stack key). True once the cast went out.
    function Heal.attach_to(cmd, pawn, target, now)
        local ability = Spell.attach(pawn)
        if not Spell.ready(ability) or not Util.valid(target) then return false end
        local slot = ability.m_eAbilitySlot or EAbilitySlots_t.ESlot_Signature_2 or 1
        local aim = aim_point(target, true)
        if not aim then return false end
        return cast_auto(cmd, target, true, aim, slot, now) == true
    end

    function Heal.host(pawn)
        if not pawn:has_modifier(MOD.ATTACHED) then return nil end
        for _, list in ipairs({ World.allies, World.troopers }) do
            for _, unit in pairs(list) do
                if Util.valid(unit) and unit:is_alive() and Util.method(unit, "has_modifier", false, MOD.HOST) == true then
                    return unit
                end
            end
        end
        return nil
    end

    function Heal.preview(pawn)
        local rows = {}
        local origin = pawn:get_origin()
        if not origin then return rows end
        local range = cast_range(pawn)
        for _, ally in ipairs(World.allies) do
            if Util.valid(ally) and ally:is_alive() then
                local ally_origin = ally:get_origin()
                local distance = ally_origin and origin:Distance(ally_origin) or math.huge
                local row = {
                    unit = ally,
                    hp = Unit.hp(ally),
                    distance = distance,
                    host = Util.method(ally, "has_modifier", false, MOD.HOST) == true,
                    healed = cfg.s2_chain and is_healed(ally) or false,
                    protected = Unit.has_any_state(ally, STATE.PROTECTED) == true,
                    in_range = distance <= range,
                }
                row.eligible = row.in_range and not row.healed and not row.protected and not row.host
                    and row.hp <= cfg.s2_ally_hp
                rows[#rows + 1] = row
            end
        end
        table.sort(rows, function(a, b)
            if a.host ~= b.host then return a.host end
            if a.eligible ~= b.eligible then return a.eligible end
            if a.eligible and cfg.s2_closest_first then return a.distance < b.distance end
            return a.hp < b.hp
        end)
        for _, row in ipairs(rows) do
            if row.eligible then
                row.next = true
                break
            end
        end
        return rows
    end

    Heal.release_alt_cast = clear_alt_cast

    function Heal.draw()
        if next(h.healed) == nil then return end
        local pawn = World.pawn
        if not pawn or not pawn:valid() or not pawn:is_alive() then return end

        local now = global_vars.curtime()
        for _, ally in ipairs(World.allies) do
            if ally:valid() and ally:is_alive() then
                local timestamp = h.healed[ally:get_handle()]
                local time_left = timestamp and K.HEAL_CHAIN_EXPIRE - (now - timestamp) or 0
                local head = time_left > 0 and Unit.bone(ally, "head") or nil
                if head then
                    local screen, visible = Render.WorldToScreen(Vector(head.x, head.y, head.z + 25))
                    if visible then
                        local fade = 1 - math.min(time_left / 5, 1)
                        Render.FilledCircle(screen, 4, Color(
                            80 + 175 * fade,
                            220 - 170 * fade,
                            255 - 205 * fade,
                            255
                        ))
                    end
                end
            end
        end
    end
end

do
    local it = {
        lock = 0.0,
        alt_item = nil,
        alt_start = 0.0,
        last_target = {},
    }

    local function convar_value(name, kind, default)
        local ok, value = pcall(function() return convar[name][kind](convar[name]) end)
        if ok and value ~= nil then return value end
        return default
    end

    local function ready(item)
        local cooldown_end = Util.number(Util.field(item, "m_flCooldownEnd", 0.0), 0.0)
        return cooldown_end <= Util.call(game_rules, "game_time", global_vars.curtime())
    end

    local function owned(pawn, name)
        local item = Util.method(pawn, "get_ability", nil, name)
        if Util.valid(item) and ready(item) then return item end
        return nil
    end

    local function bit_of(item)
        local slot = Util.field(item, "m_eAbilitySlot", nil)
        return slot and K.ITEM_BITS[slot - 3] or nil
    end

    local function press(cmd, bits)
        cmd:add_buttonstate1(bits)
        cmd:add_buttonstate2(bits)
    end

    local function aim_point(ent)
        local origin = ent:get_origin()
        return origin and Vector(origin.x, origin.y, origin.z + K.ITEM_AIM_HEIGHT) or nil
    end

    local function recently_targeted(ent, hp, threshold, now)
        local last = it.last_target[ent:get_handle()]
        return last ~= nil and now - last < K.ITEM_TARGET_GAP and hp > threshold * 0.5
    end

    local function self_cast(cmd, id, bit, now)
        local mode = convar_value("cl_citadel_ability_alt_cast_mode", "int", 2)
        if mode == 2 then
            press(cmd, bit | K.IN_ALT_CAST)
            it.alt_item = nil
            return true
        end

        local span = mode == 0
            and convar_value("cl_citadel_ability_alt_cast_hold_time", "float", 0.2) + 0.1
            or K.ALT_CAST_TAP
        if it.alt_item ~= id then
            it.alt_item, it.alt_start = id, now
        end
        local elapsed = now - it.alt_start
        if elapsed < span or (mode == 1 and elapsed >= span * 2) then
            press(cmd, bit)
            if elapsed < span then return false end
        elseif elapsed < span * 2 then
            return false
        end
        it.alt_item = nil
        return true
    end

    local function pick_ally(pawn, range, threshold, eye, now)
        local origin = pawn:get_origin()
        if not origin then return nil end
        local best, best_hp = nil, threshold
        for _, ally in ipairs(World.allies) do
            if ally:valid() and ally:is_alive() and not Unit.has_any_state(ally, STATE.PROTECTED) then
                local hp = Unit.hp(ally)
                local aim = hp < best_hp and not recently_targeted(ally, hp, threshold, now) and aim_point(ally)
                if aim and origin:Distance(aim) <= range + K.ITEM_AIM_HEIGHT and Aim.can_hit(eye, aim, ally) then
                    best, best_hp = ally, hp
                end
            end
        end
        return best
    end

    local function cast_on(cmd, eye, target, slot)
        local aim = aim_point(target)
        if cmd:can_psilent_at_pos(aim) then
            cmd:set_psilent_at_pos(aim)
        else
            cmd.ang_camera_angles = utils.calc_angle(eye, aim)
        end
        Heal.release_alt_cast(cmd)
        cmd.execute_ability_indices = (cmd.execute_ability_indices or 0) | (1 << slot)
    end

    local function try_target_item(cmd, pawn, def, now, can_aim)
        local c = def.cfg
        if not c.on or (it.alt_item and it.alt_item ~= def.id) then return false end
        local item = owned(pawn, def.item)
        local bit = item and bit_of(item)
        if not bit then return false end

        local own_hp = Unit.hp(pawn)
        if own_hp < c.self and (it.alt_item == def.id or not recently_targeted(pawn, own_hp, c.self, now)) then
            local done = self_cast(cmd, def.id, bit, now)
            if done then
                it.last_target[pawn:get_handle()] = now
                Events.emit("item", pawn, def.id)
            end
            return true, done
        end

        if not can_aim then return false end
        local eye = cmd.orig_vec_camera_position or utils.get_camera_pos()
        local range = Util.method(item, "get_scaled_property", nil, "AbilityCastRange")
        if type(range) ~= "number" or range <= 0 then return false end
        local target = pick_ally(pawn, range, c.ally, eye, now)
        if not target then return false end

        cast_on(cmd, eye, target, Util.field(item, "m_eAbilitySlot", 0))
        it.last_target[target:get_handle()] = now
        Events.emit("item", target, def.id)
        return true, true
    end

    local function count_hurt(pawn, radius)
        local origin = pawn:get_origin()
        if not origin then return 0 end
        local hurt = Unit.hp(pawn) < cfg.item_nova_hp and 1 or 0
        for _, ally in ipairs(World.allies) do
            if ally:valid() and ally:is_alive() and Unit.hp(ally) < cfg.item_nova_hp then
                local ally_origin = ally:get_origin()
                if ally_origin and origin:Distance(ally_origin) <= radius then
                    hurt = hurt + 1
                end
            end
        end
        return hurt
    end

    local function try_nova(cmd, pawn)
        local item = owned(pawn, K.NOVA_ITEM)
        local bit = item and bit_of(item)
        if not bit then return false end
        local radius = Util.method(item, "get_aoe_radius", nil)
            or Util.method(item, "get_scaled_property", nil, "Radius")
        if type(radius) ~= "number" or radius <= 0 then return false end
        if count_hurt(pawn, radius) < cfg.item_nova_count then return false end
        press(cmd, bit)
        Events.emit("item", pawn, "nova")
        return true
    end

    local function try_locket(cmd, pawn)
        if Unit.hp(pawn) >= cfg.item_locket_hp then return false end
        local item = owned(pawn, K.LOCKET_ITEM)
        local bit = item and bit_of(item)
        if not bit then return false end
        if Util.number(Util.field(item, "m_nNumStacks", 0), 0) < cfg.item_locket_stacks then return false end
        press(cmd, bit)
        Events.emit("item", pawn, "locket")
        return true
    end

    local function beam_channeling(pawn)
        local beam = Util.method(pawn, "get_ability", nil, K.BEAM_ITEM)
        return Util.field(beam, "m_bChanneling", false) == true
    end

    function Items.run(cmd, pawn, now)
        if it.alt_item and now - it.alt_start > K.ALT_CAST_TIMEOUT then
            it.alt_item = nil
        end
        if now < it.lock or beam_channeling(pawn) then return end

        local can_aim = not Heal.casted(now) and not Skill1.is_casting()
        local acted, done = false, false
        for _, def in ipairs(TARGET_ITEMS) do
            acted, done = try_target_item(cmd, pawn, def, now, can_aim)
            if acted then break end
        end
        if not acted and not it.alt_item then
            done = cfg.item_locket and try_locket(cmd, pawn)
                or cfg.item_nova and try_nova(cmd, pawn)
                or false
        end
        if done then
            it.lock = now + K.ITEM_LOCK + Util.latency() * 2
        end
    end

    function Items.cleanup(now)
        for handle, at in pairs(it.last_target) do
            if now - at > K.ITEM_TARGET_GAP then it.last_target[handle] = nil end
        end
    end
end

do
    local hs = {
        next_dispatch = 0.0,
        lock_handle = 0,
        lock_until = 0.0,
        retry_at = {},
        last_point_owner = 0,
        last_point = nil,
        candidates = nil,
        candidates_time = -math.huge,
        candidates_origin = nil,
        identities = {},
        identities_reset = 0.0,
        buff = { time = -math.huge, origin = nil, radius = 0.0, result = false },
    }

    local BREAKABLE_CLASSES = {
        "C_Citadel_BreakableProp", "C_Citadel_BreakablePropPickup", "C_Citadel_BreakblePropGoldPickup",
        "C_Citadel_BreakblePropModifierPickup", "C_Citadel_BreakblePropHealthPickup",
        "CCitadelItemPunchableNeutralGold", "C_ItemCrate",
    }
    local STATUE_CLASSES = { "CCitadelItemPickupIdol", "C_CitadelItemPickup" }
    local SINNER_CLASSES = { "C_NPC_Neutral_SinnersSacrifice", "C_NPC_Neutral_SinnersSacrifice_Hideout" }

    local BREAKABLE_CLASS_SET = {}
    for _, class_name in ipairs(BREAKABLE_CLASSES) do BREAKABLE_CLASS_SET[class_name] = true end

    local OBJECT_CLASSES = {}
    do
        local added = {}
        for _, list in ipairs({ SINNER_CLASSES, STATUE_CLASSES, BREAKABLE_CLASSES }) do
            for _, class_name in ipairs(list) do
                if not added[class_name] then
                    added[class_name] = true
                    OBJECT_CLASSES[#OBJECT_CLASSES + 1] = class_name
                end
            end
        end
    end

    local BREAKABLE_WORDS = { "item_crate", "breakable", "crate", "box", "jar", "pot", "urn", "vase", "wood", "neutral_gold" }
    local STATUE_WORDS = { "item_container", "golden", "idol", "statue" }
    local SINNER_WORDS = { "sinnerssacrifice", "sinner_sacrifice", "sinner", "sacrifice" }
    local BEARER_MODEL_WORDS = { "medic" }
    local BEARER_VDATA_WORDS = { "medic" }
    local BUFF_MODIFIERS = {
        ["ability_familiar_helpinghands/infest"] = true,
        ["helpinghands/infest"] = true,
        ["familiar_infested"] = true,
    }
    local KIND_BONUS = {
        standard_bearer = 600.0,
        sinner = 420.0,
        statue = 220.0,
        player = 150.0,
        trooper = 80.0,
    }

    local function is_enabled(kind)
        return kind ~= nil and cfg.s3_kinds[kind] == true
    end

    local function identity(ent)
        local handle = Util.handle(ent)
        local now = global_vars.curtime()
        local info = handle ~= 0 and hs.identities[handle] or nil
        if info and now < info.expires and info.expires - now < K.HELPERS_IDENTITY_TTL * 3 then return info end
        local class_name = Util.method(ent, "get_class_name", "")
        local model = Util.method(ent, "get_model_name", "")
        info = {
            class_name = class_name,
            model = string.lower(model),
            text = string.lower(table.concat({
                class_name, model,
                Util.method(ent, "get_name", ""),
                Util.method(ent, "get_vdata_class_name", ""),
            }, " ")),
            bearer = nil,
            expires = now + K.HELPERS_IDENTITY_TTL * (1 + math.random()),
        }
        if handle ~= 0 then hs.identities[handle] = info end
        return info
    end

    local function is_bearer(ent, info)
        if info.bearer ~= nil then return info.bearer end
        local result = Util.has_any(info.model, BEARER_MODEL_WORDS)
        if not result then
            result = Util.text_has_any(Util.method(ent, "get_vdata_class_name", ""), BEARER_VDATA_WORDS)
        end
        info.bearer = result
        return result
    end

    local function is_statue(ent, info)
        if Util.has_any(info.text, STATUE_WORDS) then return true end
        if Util.has_any(info.text, BREAKABLE_WORDS) then return false end
        if info.class_name == "CCitadelItemPickupIdol" then return true end
        if info.class_name == "C_CitadelItemPickup" or info.class_name == "C_ItemCrate" then
            return Util.number(Util.field(ent, "m_eLootType", -1), -1) == K.LOOT_GOLD_IDOL
        end
        return false
    end

    local function is_breakable(ent, info)
        local class_name = info.class_name
        if class_name == "C_NPC_Trooper" or class_name == "C_CitadelPlayerPawn" then return false end
        if Util.has_any(info.text, STATUE_WORDS) then return false end
        if Util.has_any(info.text, BREAKABLE_WORDS) then return true end
        local contents = Util.field(ent, "m_BreakableContentsType", nil)
        if contents ~= nil and Util.number(contents, 0) == K.BREAKABLE_EMPTY then return false end
        if class_name == "C_CitadelItemPickup" then return false end
        if class_name == "CCitadelItemPunchableNeutralGold" then return true end
        if class_name == "C_ItemCrate" then
            return Util.number(Util.field(ent, "m_eLootType", K.LOOT_NEUTRAL_GOLD), K.LOOT_NEUTRAL_GOLD) == K.LOOT_NEUTRAL_GOLD
        end
        if class_name:find("HealthPickup", 1, true) or class_name:find("ModifierPickup", 1, true) then return false end
        return BREAKABLE_CLASS_SET[class_name] == true
    end

    local function classify(ent)
        if not Util.valid(ent) then return nil end
        local info = identity(ent)
        if is_bearer(ent, info) then return "standard_bearer" end
        if info.class_name == "C_NPC_Trooper" then return "trooper" end
        if info.class_name == "C_CitadelPlayerPawn" then return "player" end
        if Util.has_any(info.text, SINNER_WORDS) then return "sinner" end
        if is_statue(ent, info) then return "statue" end
        if is_breakable(ent, info) then return "breakable" end
        return nil
    end

    local function is_in_combat(ally)
        local ally_origin = Util.origin(ally)
        local ally_team = Util.field(ally, "m_iTeamNum", nil)
        if not ally_origin or ally_team == nil then return false end
        for _, enemy in ipairs(World.enemies) do
            if Util.valid(enemy)
                and Util.method(enemy, "is_alive", false)
                and Util.field(enemy, "m_iTeamNum", nil) ~= ally_team then
                local enemy_origin = Util.origin(enemy)
                if enemy_origin and ally_origin:Distance(enemy_origin) <= cfg.s3_combat_range then
                    return true
                end
            end
        end
        return false
    end

    local function should_buff_player(ally)
        return is_enabled("player") and (not cfg.s3_combat_only or is_in_combat(ally))
    end

    local function has_buff(ent)
        for _, modifier in ipairs(Util.method(ent, "get_modifiers", {})) do
            if BUFF_MODIFIERS[string.lower(tostring(Util.method(modifier, "get_name", "")))] then
                return true
            end
        end
        return false
    end

    local function buff_nearby(pawn, origin, now)
        local cache = hs.buff
        if cache.origin
            and now - cache.time < K.HELPERS_BUFF_CACHE
            and cache.radius == cfg.s3_buff_range
            and cache.origin:Distance(origin) < 1.0 then
            return cache.result
        end

        local team = Util.field(pawn, "m_iTeamNum", nil)
        if team == nil then return false end

        local function carries_buff(ent)
            if not Util.valid(ent) or Util.field(ent, "m_iTeamNum", nil) ~= team then return false end
            local ent_origin = Util.origin(ent)
            if not ent_origin or origin:Distance(ent_origin) > cfg.s3_buff_range then return false end
            return Util.method(ent, "is_alive", false) and has_buff(ent)
        end

        local result = false
        for _, list in ipairs({ World.allies, World.troopers }) do
            for _, ent in pairs(list) do
                if carries_buff(ent) then
                    result = true
                    break
                end
            end
            if result then break end
        end

        cache.time = now
        cache.origin = origin
        cache.radius = cfg.s3_buff_range
        cache.result = result
        return result
    end

    local function make_chore(ent, kind, pawn, my_origin, now, ignore_retry)
        if not is_enabled(kind) or not Util.valid(ent) then return nil end

        local id = Util.uid(ent)
        if not ignore_retry and id ~= 0 and (hs.retry_at[id] or 0.0) > now then return nil end

        local origin = Util.origin(ent)
        if not origin or my_origin:Distance(origin) > cfg.s3_range + K.HELPERS_PREFILTER then return nil end
        if not Unit.is_active_object(ent) then return nil end
        if kind == "player" and (id == Util.uid(pawn) or not should_buff_player(ent)) then return nil end

        local center = Unit.center(ent, origin)
        local distance = my_origin:Distance(center)
        if distance > cfg.s3_range then return nil end

        return {
            entity = ent,
            id = id,
            kind = kind,
            origin = origin,
            center = center,
            priority = distance - (KIND_BONUS[kind] or 0.0),
        }
    end

    local function collect_chores(pawn, now)
        local my_origin = Util.origin(pawn)
        if not my_origin then return {} end
        if hs.candidates
            and now - hs.candidates_time < K.HELPERS_SCAN_CACHE
            and hs.candidates_origin
            and hs.candidates_origin:Distance(my_origin) < K.HELPERS_SCAN_MOVE then
            return hs.candidates
        end

        local kinds = cfg.s3_kinds
        local seen, chores = {}, {}

        local function consider(ent, kind, ignore_retry)
            local id = Util.uid(ent)
            if id == 0 or seen[id] then return end
            seen[id] = true
            local chore = make_chore(ent, kind, pawn, my_origin, now, ignore_retry)
            if chore then chores[#chores + 1] = chore end
        end

        if hs.lock_handle ~= 0 and now <= hs.lock_until then
            local locked = Util.call(entity_list, "by_handle", nil, hs.lock_handle)
            local kind = classify(locked)
            if kind then consider(locked, kind, true) end
        end

        if kinds.standard_bearer or kinds.trooper then
            for _, trooper in pairs(World.troopers) do
                if Util.valid(trooper) then
                    consider(trooper, is_bearer(trooper, identity(trooper)) and "standard_bearer" or "trooper")
                end
            end
        end

        if kinds.sinner or kinds.statue or kinds.breakable then
            local range = cfg.s3_range + K.HELPERS_PREFILTER
            for _, class_name in ipairs(OBJECT_CLASSES) do
                for _, ent in pairs(Util.call(entity_list, "by_class_name", {}, class_name)) do
                    local origin = Util.valid(ent) and Util.origin(ent)
                    if origin and my_origin:Distance(origin) <= range then
                        local kind = classify(ent)
                        if kind == "sinner" or kind == "statue" or kind == "breakable" then
                            consider(ent, kind)
                        end
                    end
                end
            end
        end

        if kinds.player then
            for _, ally in ipairs(World.allies) do
                if Util.valid(ally) then consider(ally, "player") end
            end
        end

        table.sort(chores, function(a, b) return a.priority < b.priority end)
        for i = #chores, K.HELPERS_MAX_CANDIDATES + 1, -1 do
            chores[i] = nil
        end

        hs.candidates = chores
        hs.candidates_time = now
        hs.candidates_origin = my_origin
        return chores
    end

    local function aim_points(chore)
        local points = {}
        local center, origin = chore.center, chore.origin
        local camera = utils.get_camera_pos()
        local fx, fy = 1.0, 0.0
        if camera then
            local dx, dy = center.x - camera.x, center.y - camera.y
            local len = math.sqrt(dx * dx + dy * dy)
            if len > 0.001 then fx, fy = dx / len, dy / len end
        end
        local rx, ry = -fy, fx
        local cx, cy, cz = center.x, center.y, center.z

        if hs.last_point_owner == chore.id and hs.last_point then
            points[#points + 1] = hs.last_point
        end
        points[#points + 1] = center
        points[#points + 1] = Vector(cx, cy, cz + 12)
        points[#points + 1] = Vector(cx, cy, cz - 12)
        points[#points + 1] = Vector(cx, cy, cz + 24)
        points[#points + 1] = Vector(cx, cy, cz - 24)
        points[#points + 1] = Vector(cx, cy, cz + 42)
        points[#points + 1] = Vector(cx, cy, cz - 36)
        points[#points + 1] = Vector(origin.x, origin.y, origin.z + 22)
        points[#points + 1] = Vector(origin.x, origin.y, origin.z + 44)
        points[#points + 1] = Vector(cx + rx * 16, cy + ry * 16, cz)
        points[#points + 1] = Vector(cx - rx * 16, cy - ry * 16, cz)
        points[#points + 1] = Vector(cx + rx * 32, cy + ry * 32, cz)
        points[#points + 1] = Vector(cx - rx * 32, cy - ry * 32, cz)
        points[#points + 1] = Vector(cx + fx * 18, cy + fy * 18, cz)
        points[#points + 1] = Vector(cx - fx * 18, cy - fy * 18, cz)
        points[#points + 1] = Vector(cx + rx * 24 + fx * 18, cy + ry * 24 + fy * 18, cz)
        points[#points + 1] = Vector(cx - rx * 24 - fx * 18, cy - ry * 24 - fy * 18, cz)
        return points
    end

    local function can_psilent(cmd, position) return cmd:can_psilent_at_pos(position) end
    -- Deferred p-silent: the angles are written only on the tick that dispatches the helpers.
    local function set_psilent(cmd, position) cmd:set_psilent_at_pos(position) end

    -- The engine sends helpers to the unit nearest the aim ray. Without probing get_target
    -- (which would visibly turn the hero) check that geometrically: no other unit may sit
    -- closer to the ray than the chore target, with a safety margin.
    local CLEAR_CLASSES = { "C_NPC_Trooper", "C_NPC_TrooperNeutral", "C_CitadelPlayerPawn" }
    local CLEAR_MARGIN = math.cos(math.rad(4.0))

    local function ray_cos(eye, dx, dy, dz, len, pos)
        local ox, oy, oz = pos.x - eye.x, pos.y - eye.y, pos.z - eye.z
        local olen = math.sqrt(ox * ox + oy * oy + oz * oz)
        if olen < 1 then return -1, olen end
        return (dx * ox + dy * oy + dz * oz) / (len * olen), olen
    end

    local function line_is_clear(chore, point)
        if not point or not Util.valid(chore.entity) then return false end
        local eye = utils.get_camera_pos()
        local dx, dy, dz = point.x - eye.x, point.y - eye.y, point.z - eye.z
        local len = math.sqrt(dx * dx + dy * dy + dz * dz)
        if len < 1 then return false end
        local own = Util.handle(chore.entity)
        local own_cos = ray_cos(eye, dx, dy, dz, len, point)
        local limit = math.min(own_cos, 1.0) * CLEAR_MARGIN
        for _, class in ipairs(CLEAR_CLASSES) do
            for _, unit in ipairs(entity_list.by_class_name(class) or {}) do
                if unit and unit:valid() and unit:is_alive() and Util.handle(unit) ~= own and not unit:is_dormant() then
                    local origin = Util.origin(unit)
                    local center = origin and Unit.center(unit, origin)
                    if center then
                        local c, dist = ray_cos(eye, dx, dy, dz, len, center)
                        if dist < len + 300 and c > limit then return false end
                    end
                end
            end
        end
        return true
    end

    local shop = { retry_at = 0.0, next_check = 0.0, aiming_until = 0.0, sent_at = nil, souls_at_send = nil, reported = {} }

    local function report(key, text)
        if shop.reported[key] then return end
        shop.reported[key] = true
        write_log("[Rem] " .. text)
    end

    local function controller_of(pawn)
        local handle = Util.field(pawn, "m_hController", nil)
        if not handle then return nil end
        local ok, controller = pcall(function() return entity_list.by_handle(handle) end)
        return ok and Util.valid(controller) and controller or nil
    end

    local function souls_of(pawn)
        local direct = Util.field(pawn, "m_iGold", nil)
        if type(direct) == "number" then
            report("souls", "shop: souls read from pawn.m_iGold")
            return direct
        end
        local controller = controller_of(pawn)
        local data = controller and Util.field(controller, "m_PlayerDataGlobal", nil)
        local nested = data and Util.field(data, "m_iGold", nil)
        if type(nested) == "number" then
            report("souls", "shop: souls read from controller.m_PlayerDataGlobal.m_iGold")
            return nested
        end
        local flat = controller and Util.field(controller, "m_iGold", nil)
        if type(flat) == "number" then
            report("souls", "shop: souls read from controller.m_iGold")
            return flat
        end
        report("souls_missing", "shop: souls field not found, remote quick buy disabled")
        return nil
    end

    local function queue_empty(pawn)
        local controller = controller_of(pawn)
        local queue = controller and Util.field(controller, "m_vecQuickbuyQueue", nil)
        if queue == nil then return false end
        local ok, size = pcall(function() return #queue end)
        return ok and size == 0
    end

    local function nearest_shop(pawn, origin, range)
        local team = Util.field(pawn, "m_iTeamNum", nil)
        local own, own_distance = nil, math.huge
        local enemy, enemy_distance = nil, math.huge
        for _, class_name in ipairs(K.SHOP_CLASSES) do
            for _, ent in pairs(Util.call(entity_list, "by_class_name", {}, class_name)) do
                if Util.valid(ent) then
                    local ent_team = Util.field(ent, "m_iTeamNum", team)
                    local ent_origin = Util.origin(ent)
                    local distance = ent_origin and origin:Distance(ent_origin) or math.huge
                    if distance <= range then
                        if ent_team == team or ent_team == 0 or ent_team == 1 then
                            if distance < own_distance then own, own_distance = ent, distance end
                        elseif distance < enemy_distance then
                            enemy, enemy_distance = ent, distance
                        end
                    end
                end
            end
            if own then return own, false end
        end
        if enemy and cfg.s3_shop_enemy then
            report("shop_enemy", "shop: using an enemy shop")
            return enemy, true
        end
        report("shop_missing", "shop: no shop entity found in helper range yet")
        return nil, false
    end

    local function try_shop(cmd, pawn, ability, now)
        if not cfg.s3_shop then return false end
        if not shop.sent_at and now >= shop.aiming_until and (now < shop.next_check and now > shop.next_check - 5.0) then return false end
        shop.next_check = now + 0.25
        local souls = souls_of(pawn)
        if not souls then return false end

        if shop.sent_at then
            if souls < shop.souls_at_send then
                shop.sent_at = nil
                shop.retry_at = now + 1.0
            elseif now - shop.sent_at > K.SHOP_CONFIRM then
                shop.sent_at = nil
                shop.retry_at = now + K.SHOP_RETRY
            else
                return false
            end
        end

        if now < shop.retry_at or souls < cfg.s3_shop_souls then return false end
        if Util.field(pawn, "m_bInItemShopZone", false) == true or queue_empty(pawn) then return false end
        if Util.number(Util.field(ability, "m_nAvailableHelperCount", 1), 1) <= 0 then return false end
        if Util.method(ability, "can_be_executed", 2) ~= 0 then return false end

        local origin = Util.origin(pawn)
        local range = Util.number(Util.method(ability, "get_scaled_property", nil, "AbilityCastRange"), 0)
        if range <= 0 then range = cfg.s3_range end
        local target, is_enemy = nil, false
        if origin then target, is_enemy = nearest_shop(pawn, origin, range) end
        local target_origin = target and Util.origin(target)
        if not target_origin then return false end

        local aim = Unit.center(target, target_origin)
        aim = Vector(aim.x, aim.y, math.max(aim.z, target_origin.z + K.SHOP_AIM_HEIGHT))
        local ok_can, can = pcall(can_psilent, cmd, aim)
        if not ok_can or can ~= true or not pcall(set_psilent, cmd, aim) then return false end


        Heal.release_alt_cast(cmd)
        cmd.execute_ability_indices = K.HELPERS_EXECUTE_MASK
        shop.sent_at, shop.souls_at_send = now, souls
        Events.emit("shop", target, is_enemy)
        return true
    end


    local function aim_at_chore(cmd, chore, budget)
        for _, point in ipairs(aim_points(chore)) do
            if budget <= 0 then break end
            budget = budget - 1
            local ok, allowed = pcall(can_psilent, cmd, point)
            if ok and allowed == true and pcall(set_psilent, cmd, point) then
                hs.last_point_owner = chore.id
                hs.last_point = point
                return true, budget
            end
        end
        return false, budget
    end

    local function dispatch(cmd, ability, chore, now)
        if now < hs.next_dispatch then return end
        if not Util.valid(chore.entity) or classify(chore.entity) ~= chore.kind or not is_enabled(chore.kind) then return end

        Heal.release_alt_cast(cmd)
        cmd.execute_ability_indices = K.HELPERS_EXECUTE_MASK
        if chore.id ~= 0 then
            local cooldown = Util.number(Util.method(ability, "get_scaled_property", K.HELPERS_RETRY_DELAY, "HelperChoreCooldownDuration"), K.HELPERS_RETRY_DELAY)
            hs.retry_at[chore.id] = now + math.max(K.HELPERS_RETRY_DELAY, math.min(cooldown, K.HELPERS_MAX_RETRY))
        end
        -- a cast that did not take must not be retried every tick (each try turns the hero)
        hs.next_dispatch = now + math.max(cfg.s3_delay, K.HELPERS_MIN_INTERVAL)
        if chore.kind == "sinner" then
            -- report the machine only once a helper really left (confirm_sinner)
            hs.pending_sinner = {
                entity = chore.entity,
                available = Util.number(Util.field(ability, "m_nAvailableHelperCount", -1), -1),
                at = now,
                next_check = now + 0.1,
            }
        else
            Events.emit("helpers", chore.entity, chore.kind)
        end
    end

    local function lock(chore, now)
        hs.lock_handle = Util.handle(chore.entity)
        hs.lock_until = now + K.HELPERS_LOCK_TIME
    end

    local function helpers_ready(ability)
        if Util.method(ability, "can_be_executed", 2) ~= 0 then return false end
        local available = Util.number(Util.field(ability, "m_nAvailableHelperCount", -1), -1)
        if available < 0 then
            available = Util.number(Util.method(ability, "get_scaled_property", 1, "HelperCount"), 1)
        end
        if available <= 0 then return false end
        local cooldown_end = Util.number(Util.field(ability, "m_tChoreUseCooldownEndTime", 0.0), 0.0)
        return cooldown_end <= Util.now()
    end

    local function engine_chore(ability, pawn, now)
        local target = Util.method(ability, "get_target", nil)
        local kind = classify(target)
        if not is_enabled(kind) then return nil end
        local my_origin = Util.origin(pawn)
        return my_origin and make_chore(target, kind, pawn, my_origin, now, true) or nil
    end

    local stack = { host = nil, count = 0, last_available = nil, noted = false }

    local function stack_on_host(cmd, pawn, ability)
        if not cfg.s3_stack then return false end
        local host = Heal.host(pawn)
        if not host or not Util.method(host, "get_name", ""):find("^hero_") then
            stack.host = nil
            return false
        end

        local handle = Util.handle(host)
        if handle ~= stack.host then
            stack.host, stack.count, stack.last_available, stack.noted = handle, 0, nil, false
        end
        local available = Util.number(Util.field(ability, "m_nAvailableHelperCount", -1), -1)
        if stack.last_available and available >= 0 and available < stack.last_available then
            stack.count = stack.count + (stack.last_available - available)
        end
        stack.last_available = available

        if stack.count >= cfg.s3_stack_count then
            if not stack.noted and stack.count > 0 then
                stack.noted = true
                Events.emit("helpers", host, "stack")
            end
            return false
        end
        if available == 0 or Util.method(ability, "can_be_executed", 2) ~= 0 then return false end
        if cfg.s3_stack_combat and not is_in_combat(host) then return false end

        Heal.hold_alt_cast(cmd)
        cmd.execute_ability_indices = (cmd.execute_ability_indices or 0) | K.HELPERS_EXECUTE_MASK
        return true
    end

    local key_stack = { handle = nil, count = 0, last_available = nil }

    local function stack_key_target(pawn)
        local best, best_fov = nil, K.STACK_KEY_FOV
        local my_origin = Util.origin(pawn)
        for _, ally in ipairs(World.allies) do
            local origin = Util.valid(ally) and Util.origin(ally)
            if origin and my_origin and my_origin:Distance(origin) <= cfg.s3_range then
                local fov = Unit.fov_to(Unit.center(ally, origin))
                if fov < best_fov then best, best_fov = ally, fov end
            end
        end
        return best
    end

    -- A plain targeted cast puts only one helper on a hero. Several stack only through
    -- Alt-Cast while Rem is attached to that hero, so: jump onto the ally in the crosshair,
    -- then Alt-Cast helpers onto the host. With nobody in the crosshair, stack on Rem herself.
    local function stack_by_key(cmd, pawn, ability, now)
        if not cfg.s3_stack_key then
            key_stack.handle, key_stack.count, key_stack.last_available = nil, 0, nil
            return false
        end
        local host = Heal.host(pawn)
        local aimed = stack_key_target(pawn)
        if aimed and not host then
            if now >= (key_stack.attach_at or 0) and Heal.attach_to(cmd, pawn, aimed, now) then
                key_stack.attach_at = now + 0.5
            end
            return true
        end

        local target = host or pawn
        local handle = Util.handle(target)
        if handle ~= key_stack.handle then
            key_stack.handle, key_stack.count, key_stack.last_available = handle, 0, nil
        end
        local available = Util.number(Util.field(ability, "m_nAvailableHelperCount", -1), -1)
        if key_stack.last_available and available >= 0 and available < key_stack.last_available then
            key_stack.count = key_stack.count + (key_stack.last_available - available)
            if key_stack.count >= cfg.s3_stack_count then Events.emit("helpers", target, "stack") end
        end
        key_stack.last_available = available
        if key_stack.count >= cfg.s3_stack_count or available == 0 then return true end
        if Util.method(ability, "can_be_executed", 2) ~= 0 then return true end

        Heal.hold_alt_cast(cmd)
        cmd.execute_ability_indices = (cmd.execute_ability_indices or 0) | K.HELPERS_EXECUTE_MASK
        return true
    end

    -- A dispatch can silently fail (target lost, cooldown): the machine counts as worked by our
    -- helper only once a helper is really there (an entity or modifier of ours at the machine),
    -- or the free helper count dropped. The window covers the helper's flight.
    local HELPER_WORDS = { "familiar", "helper", "chore" }

    local function helper_at(machine, pawn)
        for _, mod in ipairs(Util.method(machine, "get_modifiers", nil) or {}) do
            local ok, name = pcall(function() return mod:get_name() end)
            if ok and name and Util.has_any(string.lower(name), HELPER_WORDS) then return "modifier " .. name end
        end
        local spot = Util.origin(machine)
        if not spot then return nil end
        local own = Util.handle(pawn)
        for _, ent in ipairs(entity_list.get_all() or {}) do
            if ent ~= machine and Util.valid(ent) and Util.handle(ent) ~= own then
                local class = string.lower(Util.method(ent, "get_class_name", "") or "")
                if Util.has_any(class, HELPER_WORDS) then
                    local origin = Util.origin(ent)
                    if origin and origin:Distance(spot) < 450 then return "entity " .. class end
                end
            end
        end
        return nil
    end

    local function nearby_classes(machine)
        local spot, seen, list = Util.origin(machine), {}, {}
        if not spot then return "" end
        for _, ent in ipairs(entity_list.get_all() or {}) do
            local origin = Util.valid(ent) and Util.origin(ent)
            if origin and origin:Distance(spot) < 450 then
                local class = Util.method(ent, "get_class_name", "?") or "?"
                if not seen[class] then seen[class] = true list[#list + 1] = class end
            end
        end
        return table.concat(list, ", ")
    end

    local function confirm_sinner(ability, pawn, now)
        local pending = hs.pending_sinner
        if not pending or now < pending.next_check then return end
        pending.next_check = now + 0.1
        if not Util.valid(pending.entity) then
            hs.pending_sinner = nil
            return
        end
        local available = Util.number(Util.field(ability, "m_nAvailableHelperCount", -1), -1)
        local proof = helper_at(pending.entity, pawn)
            or (pending.available >= 0 and available >= 0 and available < pending.available and "helper count")
        if proof then
            hs.pending_sinner = nil
            if not hs.proof_logged then
                hs.proof_logged = true
                write_log("[Rem] helpers on machine confirmed by " .. tostring(proof))
            end
            -- shared with better_visuals: machine handle -> game time a helper got there
            local sent = rawget(_G, "REM_HELPER_SINNERS") or {}
            sent[Util.handle(pending.entity)] = game_rules.game_time()
            rawset(_G, "REM_HELPER_SINNERS", sent)
            Events.emit("helpers", pending.entity, "sinner")
        elseif now - pending.at > 2.5 then
            if not hs.miss_logged then
                hs.miss_logged = true
                write_log("[Rem] helpers on machine not confirmed; near it: " .. nearby_classes(pending.entity))
            end
            hs.pending_sinner = nil
        end
    end

    function Helpers.run(cmd, pawn, now)
        local ability = Spell.helpers(pawn)
        if not ability then return end
        confirm_sinner(ability, pawn, now)
        if stack_by_key(cmd, pawn, ability, now) then return end
        if stack_on_host(cmd, pawn, ability) then return end
        if try_shop(cmd, pawn, ability, now) then return end
        if not helpers_ready(ability) then return end

        local origin = Util.origin(pawn)
        if cfg.s3_check_buff and (not origin or buff_nearby(pawn, origin, now)) then return end

        -- Only chores inside a narrow cone around the crosshair: the helpers go where you look,
        -- so the one-tick cast aim never visibly turns the hero. Sinner's Sacrifice machines win.
        local direct = engine_chore(ability, pawn, now)
        local machine, other = nil, nil
        for _, chore in ipairs(collect_chores(pawn, now)) do
            if chore.center and Unit.fov_to(chore.center) <= K.HELPERS_VIEW_FOV then
                if chore.kind == "sinner" then
                    if not machine then machine = chore end
                elseif not other then
                    other = chore
                end
            end
        end

        local pick = machine
        if not pick and direct then
            lock(direct, now)
            dispatch(cmd, ability, direct, now)
            return
        end
        pick = pick or other
        if not pick then
            hs.lock_handle, hs.lock_until = 0, 0.0
            return
        end

        local aimed = aim_at_chore(cmd, pick, K.HELPERS_POINT_BUDGET)
        if not aimed then return end
        lock(pick, now)
        if pick.kind ~= "sinner" and not line_is_clear(pick, hs.last_point) then return end
        -- turn only the hero, smoothly; cast once it faces the target
        if DLCommon and DLCommon.turn_to
            and not DLCommon.turn_to(cmd, hs.last_point, K.HELPERS_TURN_SPEED, K.HELPERS_TURN_TOLERANCE) then
            return
        end
        dispatch(cmd, ability, pick, now)
    end

    function Helpers.cleanup(now)
        for id, until_time in pairs(hs.retry_at) do
            if until_time <= now then hs.retry_at[id] = nil end
        end
        if now - hs.identities_reset > K.HELPERS_IDENTITY_TTL * 5 then
            hs.identities_reset = now
            for handle, info in pairs(hs.identities) do
                if now > info.expires + K.HELPERS_IDENTITY_TTL or info.expires - now > K.HELPERS_IDENTITY_TTL * 3 then
                    hs.identities[handle] = nil
                end
            end
        end
    end
end

do
    local n = { casting = false, cast_time = -math.huge, members = nil, preview = nil }

    local function first_property(ability, names)
        for _, name in ipairs(names) do
            local value = Util.method(ability, "get_scaled_property", nil, name)
            if type(value) == "number" and value > 0 then return value end
        end
        return nil
    end

    local function shape(ability)
        local range = first_property(ability, K.NAP_RANGE_PROPS) or cfg.ult_range
        local radius = Util.method(ability, "get_aoe_radius", nil)
        if type(radius) ~= "number" or radius <= 0 then
            radius = first_property(ability, K.NAP_RADIUS_PROPS) or cfg.ult_radius
        end
        return range, radius, first_property(ability, K.NAP_CHANNEL_PROPS) or K.NAP_CHANNEL
    end

    local LEAD = 0.15

    local function future_chest(enemy)
        local origin = enemy:get_origin()
        if not origin then return nil end
        local v = Util.method(enemy, "get_velocity", nil)
        local vx, vy = v and v.x or 0, v and v.y or 0
        return Vector(origin.x + vx * LEAD, origin.y + vy * LEAD, origin.z + 50)
    end

    local function gather(eye, range, radius, camera_angles)
        local points = {}
        for _, enemy in ipairs(World.enemies) do
            local p = Util.valid(enemy) and enemy:is_alive() and not enemy:is_dormant()
                and Util.method(enemy, "is_visible", true) == true and future_chest(enemy)
            if p and eye:Distance(p) <= range + radius
                and utils.get_fov(camera_angles, utils.calc_angle(eye, p)) <= cfg.ult_fov + 10 then
                points[#points + 1] = { unit = enemy, pos = p }
            end
        end
        return points
    end

    local function caught(eye, point, points, range, radius)
        local vx, vy, vz = point.x - eye.x, point.y - eye.y, point.z - eye.z
        local len = math.sqrt(vx * vx + vy * vy + vz * vz)
        if len < 1 then return {} end
        local dx, dy, dz = vx / len, vy / len, vz / len
        local members = {}
        for _, entry in ipairs(points) do
            local px, py, pz = entry.pos.x - eye.x, entry.pos.y - eye.y, entry.pos.z - eye.z
            local along = px * dx + py * dy + pz * dz
            if along > 0 and along <= range then
                local ox, oy, oz = px - dx * along, py - dy * along, pz - dz * along
                if ox * ox + oy * oy + oz * oz <= radius * radius then
                    members[#members + 1] = entry
                end
            end
        end
        return members
    end

    local function centroid(entries)
        local x, y, z = 0, 0, 0
        for _, entry in ipairs(entries) do
            x, y, z = x + entry.pos.x, y + entry.pos.y, z + entry.pos.z
        end
        return Vector(x / #entries, y / #entries, z / #entries)
    end

    local function units(entries)
        local list = {}
        for i, entry in ipairs(entries) do list[i] = entry.unit end
        return list
    end

    local function best_direction(eye, range, radius, previous)
        local camera_angles = utils.get_camera_angles()
        local points = gather(eye, range, radius, camera_angles)
        if #points == 0 then return nil, {} end

        local candidates = {}
        for i, a in ipairs(points) do
            candidates[#candidates + 1] = a.pos
            for j = i + 1, #points do
                local b = points[j]
                candidates[#candidates + 1] = Vector((a.pos.x + b.pos.x) * 0.5, (a.pos.y + b.pos.y) * 0.5, (a.pos.z + b.pos.z) * 0.5)
            end
        end
        if #points > 2 then candidates[#candidates + 1] = centroid(points) end

        local best, best_members, best_fov = nil, nil, math.huge
        for _, point in ipairs(candidates) do
            local fov = utils.get_fov(camera_angles, utils.calc_angle(eye, point))
            if fov <= cfg.ult_fov then
                local members = caught(eye, point, points, range, radius)
                if #members > 0 then
                    local aim = centroid(members)
                    local count = #caught(eye, aim, points, range, radius)
                    if count >= #members then members = caught(eye, aim, points, range, radius) else aim = point end
                    if not best or #members > #best_members or (#members == #best_members and fov < best_fov) then
                        best, best_members, best_fov = aim, members, fov
                    end
                end
            end
        end

        if previous then
            local kept = caught(eye, previous, points, range, radius)
            if #kept > 0 and (not best or #kept >= #best_members) then
                return centroid(kept), units(kept)
            end
        end
        if not best then return nil, {} end
        return best, units(best_members)
    end

    -- Rem's own eye: range and the sleep cylinder start at her, not at the third-person camera
    local function rem_eye(pawn)
        local origin = pawn:get_origin()
        return origin and Vector(origin.x, origin.y, origin.z + 60)
    end

    function Nap.members()
        if n.casting then return n.members end
        return n.preview
    end

    function Nap.run(cmd, pawn, now)
        local ability = Util.method(pawn, "get_ability", nil, K.NAP_ABILITY)
        if not Util.valid(ability) then
            n.casting, n.preview, n.point = false, nil, nil
            return false
        end
        local eye = rem_eye(pawn)
        if not eye then return false end
        local range, radius, channel = shape(ability)

        local channeling = Util.field(ability, "m_bChanneling", false) == true
            or (n.casting and now - n.cast_time < channel)
        if channeling then
            if cfg.ult_steer then
                local point, members = best_direction(eye, range, radius, n.point)
                if point then
                    local prev, k = n.point, K.NAP_POINT_SMOOTH
                    if prev then
                        point = Vector(prev.x + (point.x - prev.x) * k, prev.y + (point.y - prev.y) * k, prev.z + (point.z - prev.z) * k)
                    end
                    n.point, n.members = point, members
                end
                if n.point then Util.face(cmd, n.point, K.NAP_STEER_SPEED) end
            end
            return true
        end
        n.casting, n.members, n.point = false, nil, nil

        local want = cfg.ult_key or cfg.ult_auto
        local ready = Util.method(ability, "can_be_executed", 1) == 0
        if not want or (not cfg.ult_key and not ready) then
            n.preview = nil
            return false
        end
        local point, members = best_direction(eye, range, radius, nil)
        n.preview = cfg.ult_key and members or nil
        if not point or not ready then return false end

        local need = cfg.ult_key and 1 or cfg.ult_auto_count
        if #members < need then return false end

        local slot = Util.field(ability, "m_eAbilitySlot", nil)
        if not slot then return false end
        -- turn the hero onto the group first, cast once it faces it
        if not Util.face(cmd, point, K.TURN_SPEED_FAST) then return true end
        cmd:set_psilent_at_pos(point)
        cmd.execute_ability_indices = (cmd.execute_ability_indices or 0) | (1 << slot)
        n.casting, n.cast_time, n.members, n.point = true, now, members, point
        Events.emit("nap", members[1], #members)
        return true
    end
end

local Marker = {}
Marker.__index = Marker

do
    local FALLBACK = Color(200, 70, 255, 255)
    local HEIGHT = 50
    local HALF = 30
    local ARM = 15
    local THICK = 9
    local SPIN = 40
    local ALPHA = 235

    function Marker.theme()
        local ok, color = pcall(Menu.Style, "primary")
        if ok and color and color.r then return color end
        return FALLBACK
    end

    function Marker.mix(a, b, k, alpha)
        return Color(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, alpha)
    end

    local mix = Marker.mix

    local function stroke(p1, p2, color, thickness)
        Render.Line(p1, p2, color, thickness)
        Render.FilledCircle(p1, thickness * 0.5, color)
        Render.FilledCircle(p2, thickness * 0.5, color)
    end

    local function soft(p1, p2, color, thick, k, ease)
        stroke(p1, p2, Color(color.r, color.g, color.b, 22 * ease), thick + 7 * k)
        stroke(p1, p2, Color(color.r, color.g, color.b, 45 * ease), thick + 3 * k)
        stroke(p1, p2, Color(color.r, color.g, color.b, ALPHA * ease), thick)
    end

    function Marker.new(scale, spin, cross)
        return setmetatable({ handle = nil, since = 0.0, scale = scale or 1.0, spin = spin or SPIN, cross = cross }, Marker)
    end

    function Marker:reset()
        self.handle = nil
    end

    function Marker:draw(target)
        local origin = target:get_origin()
        if not origin then return end
        local center, visible = Render.WorldToScreen(Vector(origin.x, origin.y, origin.z + HEIGHT))
        if not visible then return end

        local now = global_vars.curtime()
        local handle = Util.method(target, "get_handle", 0)
        if handle ~= self.handle then self.handle, self.since = handle, now end
        local t = math.min(1, (now - self.since) / 0.3)
        local ease = 1 - (1 - t) ^ 3

        local screen = Render.ScreenSize()
        local k = (screen and screen.y or 1080) / 1080 * self.scale * (1.4 - 0.4 * ease)
        local half, arm, thick = HALF * k, ARM * k, THICK * k
        local inset = half - thick * 0.5
        local angle = math.rad(now * self.spin)
        local ca, sa = math.cos(angle), math.sin(angle)

        local function at(x, y)
            return Vec2(center.x + x * ca - y * sa, center.y + x * sa + y * ca)
        end

        local top = Marker.theme()
        local bottom = mix(top, Color(255, 255, 255, 255), 0.28, 255)

        for corner = 0, 3 do
            local sx = (corner == 0 or corner == 3) and -1 or 1
            local sy = corner < 2 and -1 or 1
            local tip = at(sx * inset, sy * inset)
            local k_y = math.max(0, math.min(1, (tip.y - (center.y - half)) / (2 * half)))
            local color = mix(top, bottom, k_y, 255)
            soft(tip, at(sx * (inset - arm), sy * inset), color, thick, k, ease)
            soft(tip, at(sx * inset, sy * (inset - arm)), color, thick, k, ease)
        end

        if self.cross then
            local len = half * 0.32
            local color = mix(top, bottom, 0.5, 255)
            soft(Vec2(center.x - len, center.y), Vec2(center.x + len, center.y), color, thick * 0.8, k, ease)
            soft(Vec2(center.x, center.y - len), Vec2(center.x, center.y + len), color, thick * 0.8, k, ease)
        end
    end
end

do
    local font = Render.LoadFont("SF Pro Display", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
    local icons = Render.LoadFont("Font Awesome 6 Pro Solid", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
    local images = {}

    function Hud.scale()
        local screen = Render.ScreenSize()
        return (screen and screen.y or 1080) / 1080, screen
    end

    function Hud.text_width(text, size)
        return Render.TextSize(font, size, text).x
    end

    function Hud.text(text, x, y, size, color)
        Render.Text(font, size, text, Vec2(x + 1, y + 1), Color(0, 0, 0, math.floor(color.a * 0.6)))
        Render.Text(font, size, text, Vec2(x, y), color)
    end

    function Hud.icon(glyph, cx, cy, size, color)
        local box = Render.TextSize(icons, size, glyph)
        Render.Text(icons, size, glyph, Vec2(cx - box.x * 0.5, cy - box.y * 0.5), color)
    end

    function Hud.image(path)
        if not path then return nil end
        local cached = images[path]
        if cached == nil then
            local ok, handle = pcall(Render.LoadImage, path)
            cached = ok and handle or false
            images[path] = cached
        end
        return cached or nil
    end

    function Hud.portrait(unit)
        local name = Util.method(unit, "get_name", "")
        if name == "" or not name:find("^hero_") then return nil end
        local ok, fixed = pcall(function() return HERO_LIB.fix_hero_names[name] end)
        local short = ((ok and fixed) or name):gsub("^hero_", "")
        return Hud.image("panorama/images/heroes/" .. short .. "_sm_psd.vtex_c")
    end

    local names = {}

    local function display_name(name)
        local cached = names[name]
        if cached then return cached end
        local ok, localized = pcall(function() return GameLocalizer.Find("#" .. name) end)
        if ok and type(localized) == "string" and localized ~= "" and localized:sub(1, 1) ~= "#" then
            cached = localized
        else
            cached = (name:gsub("^hero_", ""):gsub("_", " "):gsub("^%l", string.upper))
        end
        names[name] = cached
        return cached
    end

    function Hud.name(unit)
        if not Util.valid(unit) then return "?" end
        if World.pawn and Util.method(unit, "get_handle", 0) == Util.method(World.pawn, "get_handle", 1) then
            return L("rem_text_rem")
        end
        local name = Util.method(unit, "get_name", "")
        if not name:find("^hero_") then return L("rem_text_trooper") end
        return display_name(name)
    end

    function Hud.panel(a, b, alpha, rounding)
        pcall(Render.Shadow, a, b, Color(0, 0, 0, 90 * alpha), 18, rounding)
        Render.FilledRect(a, b, Color(14, 15, 19, 222 * alpha), rounding)
        Render.Rect(a, b, Color(255, 255, 255, 14 * alpha), rounding, nil, 1)
    end

    function Hud.avatar(unit, art, cx, cy, size, alpha, glyph)
        local theme = Marker.theme()
        local image = art or (unit and Hud.portrait(unit))
        local half = size * 0.5
        if image then
            Render.Image(image, Vec2(cx - half, cy - half), Vec2(size, size), Color(255, 255, 255, 255 * alpha), size * 0.28)
        else
            Render.FilledRect(Vec2(cx - half, cy - half), Vec2(cx + half, cy + half), Color(theme.r, theme.g, theme.b, 60 * alpha), size * 0.28)
            Hud.icon(glyph or "\u{f007}", cx, cy, size * 0.5, Color(theme.r, theme.g, theme.b, 255 * alpha))
        end
    end
end

do
    local skill_marker = Marker.new(1.0, 40, false)
    local heal_marker = Marker.new(0.75, -30, true)
    local state = { rows = {}, host = nil, next_update = 0.0, alpha = 0.0 }

    function Panel.update(pawn, now)
        if now < state.next_update and now > state.next_update - 1.0 then return end
        state.next_update = now + 0.1
        state.rows = Heal.preview(pawn)
        state.host = Heal.host(pawn)
    end

    local function heal_target()
        if state.host and Util.valid(state.host) and state.host:is_alive() then return state.host end
        for _, row in ipairs(state.rows) do
            if row.next then return row.unit end
        end
        return nil
    end

    local function draw_marker(marker, target)
        if target and Util.valid(target) and target:is_alive() then
            marker:draw(target)
        else
            marker:reset()
        end
    end

    local member_markers = {}

    local function draw_members(members)
        local drawn = {}
        for _, unit in ipairs(members or {}) do
            if Util.valid(unit) and unit:is_alive() then
                local handle = Util.method(unit, "get_handle", 0)
                local marker = member_markers[handle] or Marker.new(0.7, 55, false)
                member_markers[handle] = marker
                marker:draw(unit)
                drawn[handle] = true
            end
        end
        for handle in pairs(member_markers) do
            if not drawn[handle] then member_markers[handle] = nil end
        end
        return next(drawn) ~= nil
    end

    function Panel.draw_markers()
        local members = cfg.ult_marker and Nap.members() or nil
        if not members or #members == 0 then
            members = cfg.s1_enable and cfg.s1_marker and Skill1.members() or nil
        end
        if members and #members > 1 and draw_members(members) then
            skill_marker:reset()
        else
            draw_members(nil)
            draw_marker(skill_marker, cfg.s1_enable and cfg.s1_marker and Skill1.target() or nil)
        end
        draw_marker(heal_marker, cfg.s2_enable and cfg.vis_heal_marker and heal_target() or nil)
    end

    local RED = Color(255, 90, 90, 255)

    function Panel.draw()
        local rows = state.rows
        local frame = global_vars.absoluteframetime and global_vars.absoluteframetime() or 0.016
        state.alpha = math.max(0, math.min(1, state.alpha + (#rows > 0 and 1 or -1) * frame * 6))
        local alpha = state.alpha
        if alpha <= 0 then return end

        local k, screen = Hud.scale()
        local theme = Marker.theme()
        local count = math.min(#rows, cfg.vis_panel_rows)
        local w, header, row_h, pad = 230 * k, 26 * k, 34 * k, 8 * k
        local h = header + math.max(1, count) * row_h + pad
        local x = math.max(0, math.min(screen.x - w, screen.x * cfg.vis_panel_x))
        local y = math.max(0, math.min(screen.y - h, screen.y * cfg.vis_panel_y))

        Hud.panel(Vec2(x, y), Vec2(x + w, y + h), alpha, 10 * k)
        Render.FilledRect(Vec2(x + 12 * k, y + header - 2 * k), Vec2(x + w - 12 * k, y + header - 1 * k), Color(theme.r, theme.g, theme.b, 50 * alpha), 0)
        Hud.icon("\u{f21e}", x + 18 * k, y + header * 0.5, 12 * k, Color(theme.r, theme.g, theme.b, 255 * alpha))
        Hud.text(L("rem_text_priority"), x + 30 * k, y + 6 * k, 12 * k, Color(theme.r, theme.g, theme.b, 255 * alpha))

        for i = 1, count do
            local row = rows[i]
            local top = y + header + (i - 1) * row_h + 2 * k
            local dim = (row.in_range and not row.healed and not row.protected) and 1.0 or 0.45
            local a = alpha * dim

            if row.next or row.host then
                Render.FilledRect(Vec2(x + 6 * k, top + 2 * k), Vec2(x + w - 6 * k, top + row_h - 2 * k), Color(theme.r, theme.g, theme.b, 38 * alpha), 7 * k)
                Render.FilledRect(Vec2(x + 6 * k, top + 8 * k), Vec2(x + 9 * k, top + row_h - 8 * k), Color(theme.r, theme.g, theme.b, 255 * alpha), 2 * k)
            end

            Hud.avatar(row.unit, nil, x + 28 * k, top + row_h * 0.5, 24 * k, a)
            Hud.text(Hud.name(row.unit), x + 48 * k, top + 4 * k, 13 * k, Color(240, 240, 245, 255 * a))

            local bar_x, bar_y, bar_w = x + 48 * k, top + 22 * k, 100 * k
            Render.FilledRect(Vec2(bar_x, bar_y), Vec2(bar_x + bar_w, bar_y + 4 * k), Color(255, 255, 255, 28 * a), 2 * k)
            local hp_color = Marker.mix(RED, theme, row.hp, 255 * a)
            Render.FilledRect(Vec2(bar_x, bar_y), Vec2(bar_x + bar_w * row.hp, bar_y + 4 * k), hp_color, 2 * k)
            Hud.text(string.format("%d%%", math.floor(row.hp * 100 + 0.5)), bar_x + bar_w + 6 * k, top + 17 * k, 11 * k, Color(200, 200, 210, 255 * a))

            local right = x + w - 14 * k
            local distance = row.distance < math.huge and string.format("%dm", math.floor(row.distance / K.UNIT_METER + 0.5)) or ""
            local dw = Hud.text_width(distance, 11 * k)
            Hud.text(distance, right - dw, top + 4 * k, 11 * k, Color(150, 152, 162, 255 * a))

            local tag, glyph = nil, nil
            if row.host then
                tag, glyph = L("rem_text_host"), "\u{f0c1}"
            elseif row.next then
                tag, glyph = L("rem_text_next"), "\u{f04b}"
            elseif row.healed then
                glyph = "\u{f00c}"
            end
            if tag then
                local tw = Hud.text_width(tag, 10 * k)
                Hud.text(tag, right - tw, top + 18 * k, 10 * k, Color(theme.r, theme.g, theme.b, 255 * alpha))
                Hud.icon(glyph, right - tw - 9 * k, top + 24 * k, 9 * k, Color(theme.r, theme.g, theme.b, 255 * alpha))
            elseif glyph then
                Hud.icon(glyph, right - 6 * k, top + 24 * k, 10 * k, Color(150, 220, 150, 255 * a))
            end
        end
    end
end

do
    local notes = {}
    local MAX_NOTES = 5
    local ITEM_ART = {
        barrier = "panorama/images/items/vitality/divine_barrier_psd.vtex_c",
        ward = "panorama/images/items/vitality/guardian_ward_psd.vtex_c",
        beam = "panorama/images/items/vitality/rescue_beam_psd.vtex_c",
        rite = "panorama/images/items/vitality/healing_rite_psd.vtex_c",
        nova = "panorama/images/items/vitality/healing_nova_psd.vtex_c",
        locket = "panorama/images/items/vitality/restorative_locket_psd.vtex_c",
    }
    local KIND_LABEL = {}
    for _, target in ipairs(HELPER_TARGETS) do KIND_LABEL[target.kind] = target.id end

    local function build(kind, entity, extra)
        if kind == "jump" then
            local hp = Util.valid(entity) and string.format(" · %d%%", math.floor(Unit.hp(entity) * 100 + 0.5)) or ""
            local text = extra == "panic" and "rem_text_panic" or (extra and "rem_text_jump" or "rem_text_self")
            return { unit = entity, title = Hud.name(entity), sub = L(text) .. hp, glyph = "\u{f70c}" }
        elseif kind == "attach" then
            return { unit = entity, title = Hud.name(entity), sub = L("rem_text_attach"), glyph = "\u{f0c1}" }
        elseif kind == "item" then
            return {
                art = Hud.image(ITEM_ART[extra]),
                title = L("rem_item_" .. tostring(extra)),
                sub = string.format(L("rem_text_item"), Hud.name(entity)),
                glyph = "\u{f479}",
            }
        elseif kind == "helpers" and extra == "stack" then
            return { unit = entity, title = "Lil Helpers", sub = string.format(L("rem_text_stack"), Hud.name(entity)), glyph = "\u{f5fd}" }
        elseif kind == "helpers" and extra == "sinner" then
            return { title = "Lil Helpers", sub = L("rem_text_helpers_casino"), glyph = "\u{f522}" }
        elseif kind == "helpers" then
            return { title = "Lil Helpers", sub = L("rem_text_helpers") .. " · " .. (KIND_LABEL[extra] or tostring(extra)), glyph = "\u{f0c0}" }
        elseif kind == "shop" then
            return { title = L("rem_text_shop") .. (extra and " · " .. L("rem_s3_shop_enemy") or ""), sub = L("rem_text_shop_sub"), glyph = "\u{f07a}" }
        elseif kind == "nap" then
            return { unit = entity, title = L("rem_text_nap"), sub = string.format(L("rem_text_nap_sub"), extra or 0), glyph = "\u{f236}" }
        elseif kind == "pillow" then
            return { unit = entity, title = L("rem_text_pillow"), sub = string.format(L("rem_text_pillow_sub"), extra or 0), glyph = "\u{f236}" }
        elseif kind == "chain" then
            return { title = L("rem_text_chain"), sub = L("rem_text_chain_sub"), glyph = "\u{f0e2}" }
        end
        return nil
    end

    function Notify.push(kind, entity, extra)
        if not cfg.vis_notify or not cfg.vis_events[kind] then return end
        local note = build(kind, entity, extra)
        if not note then return end
        local now = global_vars.curtime()
        local last = notes[1]
        if last and last.title == note.title and last.sub == note.sub and now - last.born < 0.8 then return end
        note.born = now
        note.slot = 0
        table.insert(notes, 1, note)
        for i = #notes, MAX_NOTES + 1, -1 do notes[i] = nil end
    end

    function Notify.draw()
        if #notes == 0 then return end
        local now = global_vars.curtime()
        local life = cfg.vis_notify_time
        local k, screen = Hud.scale()
        local theme = Marker.theme()
        local frame = global_vars.absoluteframetime and global_vars.absoluteframetime() or 0.016
        local glide = math.min(1, frame * 12)
        local h, gap = 46 * k, 6 * k
        local right = screen.x * cfg.vis_notify_x
        local bottom = screen.y * cfg.vis_notify_y

        for i = #notes, 1, -1 do
            if now - notes[i].born > life then table.remove(notes, i) end
        end

        for i, note in ipairs(notes) do
            note.slot = note.slot + ((i - 1) - note.slot) * glide
            local age = now - note.born
            local enter = math.min(1, age / 0.25)
            enter = 1 - (1 - enter) ^ 3
            local alpha = math.min(enter, math.max(0, math.min(1, (life - age) / 0.35)))

            local title_w = Hud.text_width(note.title, 13 * k)
            local sub_w = Hud.text_width(note.sub, 11 * k)
            local w = math.max(title_w, sub_w) + 64 * k
            local x = math.min(screen.x - w - 4 * k, right - w) + (1 - enter) * 40 * k
            local y = bottom - h - note.slot * (h + gap)

            Hud.panel(Vec2(x, y), Vec2(x + w, y + h), alpha, 10 * k)
            Render.FilledRect(Vec2(x + 5 * k, y + 9 * k), Vec2(x + 8 * k, y + h - 9 * k), Color(theme.r, theme.g, theme.b, 255 * alpha), 2 * k)
            Hud.avatar(note.unit, note.art, x + 30 * k, y + h * 0.5, 28 * k, alpha, note.glyph)
            Hud.text(note.title, x + 52 * k, y + 7 * k, 13 * k, Color(242, 242, 247, 255 * alpha))
            Hud.text(note.sub, x + 52 * k, y + 25 * k, 11 * k, Color(150, 152, 162, 255 * alpha))

            local left = math.max(0, 1 - age / life)
            Render.FilledRect(Vec2(x + 12 * k, y + h - 3 * k), Vec2(x + 12 * k + (w - 24 * k) * left, y + h - 2 * k), Color(theme.r, theme.g, theme.b, 160 * alpha), 1)
        end
    end
end

local menu_next = 0.0

local function refresh_menu()
    local now = global_vars.curtime()
    if now >= menu_next or now < menu_next - 1.0 then
        menu_next = now + 0.1
        read_menu()
        rawset(_G, "REM_ASSISTANT_ENABLED", cfg.enable == true)
    else
        cfg.s1_key = ui.s1_key:IsDown()
        cfg.s2_key = ui.s2_key:IsDown()
        cfg.ult_key = ui.ult_key:IsDown()
    end
end

local status_next = 0
local function status_log(now)
    if now < status_next then return end
    status_next = now + 5
    local pawn = World.pawn
    local ok_name, name = pcall(function() return pawn and pawn:get_name() end)
    write_log(string.format("[Rem] status: enable=%s pawn=%s alive=%s name=%s is_rem=%s heal=%s helpers=%s items=%s allies=%d enemies=%d",
        tostring(cfg.enable), tostring(pawn ~= nil), tostring(pawn and pawn:is_alive()), tostring(ok_name and name),
        tostring(World.is_rem), tostring(cfg.s2_enable), tostring(cfg.s3_enable), tostring(cfg.items_enable),
        #(World.allies or {}), #(World.enemies or {})))
end

callback.on_pre_createmove:set(function(cmd)
    if DLCommon and DLCommon.shim then DLCommon.shim(cmd) end
    if DLCommon and DLCommon.turn_begin then pcall(DLCommon.turn_begin, cmd) end
    rawset(_G, "DL_MODULE", "rem.tick")
    refresh_menu()
    pcall(status_log, os.clock())
    if not cfg.enable then return end

    local now = global_vars.curtime()
    World.refresh(now)

    local pawn = World.pawn
    if not pawn or not pawn:is_alive() then return end
    if not World.is_rem then
        if Skill1.is_casting() then Skill1.reset() end
        return
    end

    for _, enemy in ipairs(World.enemies) do
        Track.velocity(enemy)
    end
    Heal.expire(now)

    local attached = pawn:has_modifier(MOD.ATTACHED)
    if cfg.s2_enable and cfg.s2_chain then
        Heal.track_chain(pawn, now)
    end

    local napping = false
    Util.safe("naptime", function() napping = Nap.run(cmd, pawn, now) end)
    if cfg.s1_enable and not napping then
        Util.safe("skill1", Skill1.run, cmd, pawn, World.enemies, now)
    end
    if not napping then
        Util.safe("heal", Heal.run, cmd, pawn, now, attached)
        if cfg.items_enable then
            Util.safe("items", Items.run, cmd, pawn, now)
        end
        if cfg.s3_enable then
            Util.safe("helpers", Helpers.run, cmd, pawn, now)
        end
    end
    -- Auto Alt-Cast goes last and only on ticks that cast nothing: the new input API cannot
    -- release a button within the same tick, and helpers cast with Alt held go onto the host.
    if cfg.s2_auto_alt and attached and (cmd.execute_ability_indices or 0) == 0 then
        Heal.hold_alt_cast(cmd)
    end
    Util.safe("panel", Panel.update, pawn, now)
end)

callback.on_draw:set(function()
    if not cfg.enable or not World.is_rem then return end
    if cfg.s2_draw_chain then Util.safe("draw_chain", Heal.draw) end
    Util.safe("draw_markers", Panel.draw_markers)
    if cfg.vis_panel then Util.safe("draw_panel", Panel.draw) end
    if cfg.vis_notify then Util.safe("draw_notify", Notify.draw) end
end)
