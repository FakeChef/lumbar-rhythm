import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_data_refresh.dart';
import '../../../core/widgets/header_action_button.dart';
import '../../reports/application/daily_report_controller.dart';
import '../../recovery/data/recovery_repository.dart';
import '../../recovery/domain/daily_recovery_note.dart';
import '../../recovery/domain/recovery_profile.dart';
import '../data/rehab_repository.dart';
import '../domain/action_item.dart';

class ActionsPage extends ConsumerStatefulWidget {
  const ActionsPage({super.key});

  @override
  ConsumerState<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends ConsumerState<ActionsPage> {
  String? _selectedPhase;

  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(_rehabPageDataProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        pageState.when(
          loading: () => const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('正在读取康复模板'),
            ),
          ),
          error: (error, stackTrace) => Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('康复模板读取失败'),
              trailing: TextButton(
                onPressed: () => ref.invalidate(_rehabPageDataProvider),
                child: const Text('重试'),
              ),
            ),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RehabHeaderCard(
                onAdd: () => _showAddLogPicker(context, ref, data),
              ),
              const SizedBox(height: 20),
              _DailyRecoveryNoteCard(
                noteState: data.dailyNoteState,
                onEdit: () => _showDailyRecoveryNoteDialog(
                  context,
                  ref,
                  data.dailyNoteState.note,
                ),
              ),
              const SizedBox(height: 20),
              _TodayRehabLogListCard(data: data),
              const SizedBox(height: 20),
              _PhaseActivitySection(
                data: data,
                selectedPhase: _selectedPhase ?? data.currentPhase,
                onPhaseChanged: (phase) {
                  setState(() => _selectedPhase = phase);
                },
              ),
              const SizedBox(height: 20),
              const _RehabPhaseGuideCard(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showDailyRecoveryNoteDialog(
    BuildContext context,
    WidgetRef ref,
    DailyRecoveryNote? note,
  ) async {
    final result = await showModalBottomSheet<_DailyRecoveryNoteDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DailyRecoveryNoteSheet(note: note),
    );
    if (result == null) {
      return;
    }

    await ref.read(recoveryRepositoryProvider).saveNote(
          date: DateTime.now(),
          overallFeeling: result.overallFeeling,
          backPainScore: result.backPainScore,
          legSymptomScore: result.legSymptomScore,
          fatigueScore: result.fatigueScore,
          tags: result.tags,
          note: result.note,
        );
    ref.invalidate(_rehabPageDataProvider);
    ref.invalidate(dailyReportControllerProvider);
    ref.read(appDataRefreshProvider.notifier).state++;
  }

  Future<void> _showLogDialog(
    BuildContext context,
    WidgetRef ref,
    RehabAction action,
  ) async {
    final result = await showRehabLogSheet(context: context, action: action);
    if (result == null) {
      return;
    }

    await saveRehabLogDraft(ref, action: action, draft: result);
    ref.invalidate(_rehabPageDataProvider);
    _refreshRehabData(ref);

    if (!context.mounted) {
      return;
    }

    _showRehabLogSavedFeedback(context, action, result);
  }

  Future<void> _showAddLogPicker(
    BuildContext context,
    WidgetRef ref,
    _RehabPageData data,
  ) async {
    final actions = data.actions;
    if (actions.isEmpty) {
      return;
    }
    String? selectedCategory = _availableCategories(actions).firstOrNull;
    int? selectedActionId = actions.firstOrNull?.id;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final categories = _availableCategories(actions);
            selectedCategory = categories.contains(selectedCategory)
                ? selectedCategory
                : categories.firstOrNull;
            final categoryActions = actions
                .where(
                    (action) => _categoryForAction(action) == selectedCategory)
                .toList();
            selectedActionId =
                categoryActions.any((action) => action.id == selectedActionId)
                    ? selectedActionId
                    : categoryActions.firstOrNull?.id;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: _RehabActionPickerCard(
                  categories: categories,
                  actions: categoryActions,
                  selectedCategory: selectedCategory,
                  selectedActionId: selectedActionId,
                  onCategoryChanged: (value) {
                    final firstAction = actions
                        .where((action) => _categoryForAction(action) == value)
                        .toList()
                        .firstOrNull;
                    setSheetState(() {
                      selectedCategory = value;
                      selectedActionId = firstAction?.id;
                    });
                  },
                  onActionChanged: (value) {
                    setSheetState(() => selectedActionId = value);
                  },
                  onRecord: () async {
                    final selectedAction = data.actionById(selectedActionId);
                    if (selectedAction == null) {
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                    await _showLogDialog(context, ref, selectedAction);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Future<RehabLogDraft?> showRehabLogSheet({
  required BuildContext context,
  required RehabAction action,
  DateTime? initialDate,
}) {
  return showModalBottomSheet<RehabLogDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) => RehabLogSheet(
      action: action,
      initialDate: initialDate,
    ),
  );
}

Future<void> saveRehabLogDraft(
  WidgetRef ref, {
  required RehabAction action,
  required RehabLogDraft draft,
}) async {
  await ref.read(rehabRepositoryProvider).addLog(
        action: action,
        amount: draft.amount,
        unit: draft.unit,
        reaction: draft.reaction,
        symptomTags: draft.symptomTags,
        note: draft.note,
        createdAt: draft.createdAt,
      );
}

void refreshRehabRecordProviders(WidgetRef ref) {
  _refreshRehabData(ref);
}

void _refreshRehabData(WidgetRef ref) {
  ref.invalidate(dailyReportControllerProvider);
  ref.read(appDataRefreshProvider.notifier).state++;
}

void _showRehabLogSavedFeedback(
  BuildContext context,
  RehabAction action,
  RehabLogDraft draft,
) {
  if (draft.reaction == RehabReaction.muchWorse) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('建议减少量、暂停观察，必要时咨询医生或康复师。'),
      ),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('已记录：${action.name}')),
  );
}

class _RehabHeaderCard extends StatelessWidget {
  const _RehabHeaderCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.self_improvement_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 34,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日康复记录',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '记录今天做了什么、做了多少、做后感觉如何。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '这里是记录工具，不是康复处方。\n不舒服时可以休息。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
            HeaderActionButton(
              key: const ValueKey('rehab-add-entry-button'),
              tooltip: '添加康复记录',
              onPressed: onAdd,
              icon: Icons.add,
            ),
          ],
        ),
      ),
    );
  }
}

final _rehabPageDataProvider = FutureProvider<_RehabPageData>((ref) async {
  ref.watch(appDataRefreshProvider);
  final repository = ref.watch(rehabRepositoryProvider);
  final recoveryRepository = ref.watch(recoveryRepositoryProvider);
  final actions = await repository.loadActions();
  final todayLogs = await repository.loadToday();
  final profile = await recoveryRepository.loadProfile();
  _DailyRecoveryNoteLoadState dailyNoteState;
  try {
    dailyNoteState = _DailyRecoveryNoteLoadState.loaded(
      await recoveryRepository.loadNote(DateTime.now()),
    );
  } catch (_) {
    dailyNoteState = const _DailyRecoveryNoteLoadState.failed();
  }
  return _RehabPageData(
    actions: actions,
    todayLogs: todayLogs,
    profile: profile,
    dailyNoteState: dailyNoteState,
  );
});

class _RehabPageData {
  const _RehabPageData({
    required this.actions,
    required this.todayLogs,
    required this.profile,
    required this.dailyNoteState,
  });

  final List<RehabAction> actions;
  final List<RehabLog> todayLogs;
  final RecoveryProfile? profile;
  final _DailyRecoveryNoteLoadState dailyNoteState;

  String get currentPhase {
    return rehabPhaseForPostSurgeryDay(profile?.postSurgeryDay(DateTime.now()));
  }

  List<RehabAction> get recordableActions {
    return actions.where((action) {
      final activity = activityForAction(action);
      return activity == null ||
          activity.isDefaultVisible ||
          activity.riskLevel != 'high';
    }).toList();
  }

  List<RehabAction> visibleActionsForPhase(String phase) {
    return actions.where((action) {
      final activity = activityForAction(action);
      return activity != null &&
          activity.isDefaultVisible &&
          rehabActivityIsInPhase(activity, phase);
    }).toList();
  }

  List<RehabActivity> conditionalActivitiesForPhase(String phase) {
    return activityMasterV1.where((activity) {
      return !activity.isDefaultVisible &&
          activity.riskLevel != 'high' &&
          rehabActivityIsInPhase(activity, phase);
    }).toList();
  }

  RehabAction? actionById(int? actionId) {
    if (actionId == null) {
      return null;
    }
    for (final action in actions) {
      if (action.id == actionId) {
        return action;
      }
    }
    return null;
  }

  String actionNameFor(int actionId) {
    for (final action in actions) {
      if (action.id == actionId) {
        return action.name;
      }
    }
    return legacyActionNameForId(actionId) ?? '未知活动';
  }
}

class _DailyRecoveryNoteLoadState {
  const _DailyRecoveryNoteLoadState._({
    required this.isFailed,
    this.note,
  });

  const _DailyRecoveryNoteLoadState.loaded(DailyRecoveryNote? note)
      : this._(isFailed: false, note: note);

  const _DailyRecoveryNoteLoadState.failed() : this._(isFailed: true);

  final bool isFailed;
  final DailyRecoveryNote? note;
}

class _DailyRecoveryNoteCard extends StatelessWidget {
  const _DailyRecoveryNoteCard({
    required this.noteState,
    required this.onEdit,
  });

  final _DailyRecoveryNoteLoadState noteState;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final value = noteState.note;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '每日康复小结',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              noteState.isFailed
                  ? '今日小结暂时无法读取，可稍后重试。'
                  : value == null
                      ? '用点选方式记录今天的整体感受。'
                      : '${value.overallFeeling.label} · 腰 ${value.backPainScore} · '
                          '腿 ${value.legSymptomScore} · 疲劳 ${value.fatigueScore}',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_note_outlined),
              label: Text(value == null ? '记录今日小结' : '修改今日小结'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayRehabLogListCard extends StatelessWidget {
  const _TodayRehabLogListCard({required this.data});

  final _RehabPageData data;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('rehab-today-records-section'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '今天已记录',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              if (data.todayLogs.isEmpty)
                Text(
                  '今天还没有康复记录，记录一点也有价值。',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                for (final log in data.todayLogs) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(data.actionNameFor(log.actionId)),
                    subtitle: Text(
                      '${_formatNumber(log.amountValue)} ${log.unit} · ${log.reaction.label}',
                    ),
                    trailing: Text(_formatTime(log.createdAt)),
                  ),
                  if (log != data.todayLogs.last) const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseActivitySection extends StatelessWidget {
  const _PhaseActivitySection({
    required this.data,
    required this.selectedPhase,
    required this.onPhaseChanged,
  });

  final _RehabPageData data;
  final String selectedPhase;
  final ValueChanged<String> onPhaseChanged;

  @override
  Widget build(BuildContext context) {
    final actions = data.visibleActionsForPhase(selectedPhase);
    final moreActivities = data.conditionalActivitiesForPhase(selectedPhase);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${rehabPhaseTitle(selectedPhase)}活动',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              rehabPhaseDescription(selectedPhase),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              '根据你的手术日期，当前默认显示本阶段活动；你也可以切换其他阶段，仅用于记录。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                for (final phase in rehabPhases)
                  ButtonSegment(
                    value: phase,
                    label: Text(phase),
                  ),
              ],
              selected: {selectedPhase},
              onSelectionChanged: (values) => onPhaseChanged(values.single),
            ),
            const SizedBox(height: 12),
            if (actions.isEmpty)
              const Text('这个阶段暂无默认显示活动，可以先记录今天已经完成的内容。')
            else
              for (final action in actions) ...[
                _PhaseActivityTile(action: action),
                if (action != actions.last) const Divider(height: 16),
              ],
            if (moreActivities.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('更多活动'),
                subtitle: const Text('条件显示动作，记录前请以自身舒适度为准。'),
                children: [
                  for (final activity in moreActivities)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(activity.nameCn),
                      subtitle: Text(activity.patientTip),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhaseActivityTile extends StatelessWidget {
  const _PhaseActivityTile({required this.action});

  final RehabAction action;

  @override
  Widget build(BuildContext context) {
    final activity = activityForAction(action);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_categoryIcon(_categoryForAction(action))),
      title: Text(action.name),
      subtitle: Text(activity?.patientTip ?? action.guidance),
      trailing: Text(_categoryLabel(_categoryForAction(action))),
    );
  }
}

class _RehabActionPickerCard extends StatelessWidget {
  const _RehabActionPickerCard({
    required this.categories,
    required this.actions,
    required this.selectedCategory,
    required this.selectedActionId,
    required this.onCategoryChanged,
    required this.onActionChanged,
    required this.onRecord,
  });

  final List<String> categories;
  final List<RehabAction> actions;
  final String? selectedCategory;
  final int? selectedActionId;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<int?> onActionChanged;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final selectedAction = _selectedActionOrNull(actions, selectedActionId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('rehab-category-dropdown'),
              initialValue: selectedCategory,
              decoration: const InputDecoration(labelText: '选择分类'),
              items: [
                for (final category in categories)
                  DropdownMenuItem(
                    value: category,
                    child: Text(_categoryLabel(category)),
                  ),
              ],
              onChanged: onCategoryChanged,
            ),
            if (selectedAction != null) ...[
              const SizedBox(height: 12),
              _SelectedActivityInfo(action: selectedAction),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: const ValueKey('rehab-activity-dropdown'),
              initialValue: selectedActionId,
              decoration: const InputDecoration(labelText: '选择活动'),
              items: [
                for (final action in actions)
                  DropdownMenuItem(
                    value: action.id,
                    child: Text(action.name),
                  ),
              ],
              onChanged: onActionChanged,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '+ 添加康复记录',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('rehab-add-log'),
              onPressed: actions.isEmpty ? null : onRecord,
              icon: const Icon(Icons.add),
              label: const Text('+ 添加康复记录'),
            ),
          ],
        ),
      ),
    );
  }
}

RehabAction? _selectedActionOrNull(List<RehabAction> actions, int? actionId) {
  for (final action in actions) {
    if (action.id == actionId) {
      return action;
    }
  }
  return null;
}

class _SelectedActivityInfo extends StatelessWidget {
  const _SelectedActivityInfo({required this.action});

  final RehabAction action;

  @override
  Widget build(BuildContext context) {
    final activity = activityForAction(action);
    if (activity == null) {
      return const SizedBox.shrink();
    }
    final needsGuidance =
        activity.requiresDoctorClearance || activity.riskLevel == 'high';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_phaseRangeLabel(activity)} · ${_categoryLabel(activity.category)} · ${_riskLabel(activity.riskLevel)}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(activity.patientTip),
            const SizedBox(height: 4),
            Text('暂停提示：${activity.stopRule}'),
            if (needsGuidance) ...[
              const SizedBox(height: 8),
              const Text('该活动更适合后期或专业指导下记录，请以医生或康复师建议为准。'),
            ],
          ],
        ),
      ),
    );
  }
}

class _RehabPhaseGuideCard extends StatelessWidget {
  const _RehabPhaseGuideCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('康复阶段说明'),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          Text(
            _rehabPhaseGuideText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

const _categoryOrder = [
  'WALK',
  'BREAK',
  'BASIC',
  'CORE',
  'HIP_LEG',
  'MOBILITY',
  'AEROBIC',
  'SPORT',
  'FUNCTION',
];

List<String> _availableCategories(List<RehabAction> actions) {
  final available = actions.map(_categoryForAction).toSet();
  return [
    ..._categoryOrder.where(available.contains),
    ...available.where((category) => !_categoryOrder.contains(category)),
  ];
}

String _categoryForAction(RehabAction action) {
  final direct = action.category;
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }
  for (final builtIn in actionLibrary) {
    if (builtIn.id == action.id) {
      return builtIn.category ?? 'BASIC';
    }
  }
  return 'BASIC';
}

String _categoryLabel(String category) {
  return switch (category) {
    'WALK' => '步行与有氧',
    'BREAK' => '坐站节奏',
    'BASIC' => '早期基础',
    'CORE' => '核心稳定',
    'HIP_LEG' => '臀腿力量',
    'MOBILITY' => '灵活性活动',
    'AEROBIC' => '低冲击有氧',
    'SPORT' => '运动能力',
    'FUNCTION' => '功能活动',
    _ => category,
  };
}

IconData _categoryIcon(String category) {
  return switch (category) {
    'WALK' => Icons.directions_walk_outlined,
    'BASIC' => Icons.spa_outlined,
    'CORE' => Icons.accessibility_new_outlined,
    'HIP_LEG' => Icons.airline_seat_legroom_extra_outlined,
    'MOBILITY' => Icons.self_improvement_outlined,
    'AEROBIC' => Icons.directions_bike_outlined,
    'SPORT' => Icons.sports_handball_outlined,
    'FUNCTION' => Icons.work_outline,
    _ => Icons.radio_button_checked,
  };
}

String _phaseRangeLabel(RehabActivity activity) {
  final start = rehabPhaseTitle(activity.phaseStart);
  final end = rehabPhaseTitle(activity.phaseEnd);
  return start == end ? start : '$start-$end';
}

String _riskLabel(String riskLevel) {
  return switch (riskLevel) {
    'low' => '低风险',
    'medium' => '中等风险',
    'high' => '高风险',
    _ => riskLevel,
  };
}

const _rehabPhaseGuideText =
    '本康复计划参考运动医学中的组织愈合节律构建。人体修复并非线性过程，通常会经历炎症消退、组织增生、胶原纤维重塑到功能成熟等阶段。\n\n'
    '我们将其划分为四个阶段，目的是让康复记录节奏与身体的修复节奏更好同步：\n\n'
    '第1阶段（0-4周）：急性愈合与神经唤醒。聚焦早期管理，通过轻柔活动保护受影响组织，减少早期过度负荷带来的不适。\n\n'
    '第2阶段（4-8周）：运动控制与动态稳定。针对组织增生期，重点在于通过温和运动，把零散的活动体验转化为更有序的受控力量。\n\n'
    '第3阶段（8-12周）：功能性负荷进阶。对应组织重塑成熟期，通过功能性负荷训练，逐步提升胶原纤维的承受能力，重建日常活动信心。\n\n'
    '第4阶段（12周后）：高负荷恢复。针对组织功能成熟期，由受控训练逐步过渡至自主运动，帮助回归正常生活与运动状态。\n\n'
    '这套分期体系用于提供对应的心理与行动支持，帮助你稳步找回身体的掌控感。';

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull {
    return isEmpty ? null : first;
  }
}

Color _reactionColor(RehabReaction reaction) {
  return switch (reaction) {
    RehabReaction.moreComfortable => const Color(0xFF27AE60),
    RehabReaction.noChange => const Color(0xFF64748B),
    RehabReaction.slightlyWorse => const Color(0xFFF2994A),
    RehabReaction.muchWorse => const Color(0xFFEB5757),
  };
}

IconData _reactionIcon(RehabReaction reaction) {
  return switch (reaction) {
    RehabReaction.moreComfortable => Icons.sentiment_satisfied_outlined,
    RehabReaction.noChange => Icons.remove_circle_outline,
    RehabReaction.slightlyWorse => Icons.warning_amber_outlined,
    RehabReaction.muchWorse => Icons.error_outline,
  };
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

String _formatAmount(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

double _stepForUnit(String unit) {
  return switch (unit) {
    '分钟' || '秒' => 1,
    _ => 1,
  };
}

List<String> _unitOptionsFor(RehabAction action) {
  final units = [
    action.defaultUnit,
    ...action.optionalUnits,
  ].where((unit) => unit.trim().isNotEmpty).toSet().toList();
  return units.isEmpty ? [action.defaultUnit] : units;
}

String _formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDate(DateTime date) {
  return '${date.year}年${date.month}月${date.day}日';
}

class _QuickAmount {
  const _QuickAmount(this.amount, this.unit);

  final String amount;
  final String unit;

  String get label => '$amount$unit';
}

List<_QuickAmount> _quickAmountsFor(RehabAction action) {
  return switch (action.name) {
    '短距离步行' || '平地步行' || '分段步行' || '连续步行耐力' => const [
        _QuickAmount('3', '分钟'),
        _QuickAmount('5', '分钟'),
        _QuickAmount('10', '分钟'),
      ],
    '膈式呼吸' ||
    '腹式呼吸' ||
    '骨盆中立训练' ||
    '固定式自行车' ||
    '固定自行车' ||
    '水中康复与游泳' ||
    '轻松游泳/水中步行' ||
    '站立姿势重置' =>
      const [
        _QuickAmount('3', '分钟'),
        _QuickAmount('5', '分钟'),
      ],
    '久坐中断' || '久站中断' => const [
        _QuickAmount('1', '次/天'),
        _QuickAmount('3', '次/天'),
      ],
    '腹部轻收缩' || '改良侧桥' || '腘绳肌轻拉伸' || '髋屈肌拉伸' => const [
        _QuickAmount('10', '秒'),
        _QuickAmount('20', '秒'),
      ],
    '踝泵' ||
    '足跟滑动' ||
    '仰卧交替抬腿' ||
    '臀桥' ||
    '蚌式开合' ||
    '站姿髋外展' ||
    '站姿提踵' ||
    '扶桌半蹲' ||
    'Bird-dog 简化版' ||
    '弹力带抗旋转' =>
      const [
        _QuickAmount('5', '次'),
        _QuickAmount('10', '次'),
      ],
    _ => [
        _QuickAmount('1', action.defaultUnit),
        _QuickAmount('5', action.defaultUnit),
      ],
  };
}

class RehabLogSheet extends StatefulWidget {
  const RehabLogSheet({
    required this.action,
    this.initialDate,
    super.key,
  });

  final RehabAction action;
  final DateTime? initialDate;

  @override
  State<RehabLogSheet> createState() => _RehabLogSheetState();
}

class _RehabLogSheetState extends State<RehabLogSheet> {
  static const _symptomTagOptions = ['腰酸', '腰痛', '腿麻', '脚背刺痛', '疲劳'];

  final _noteController = TextEditingController();
  late double _amount;
  late String _unit;
  late DateTime _createdAt;
  RehabReaction _reaction = RehabReaction.noChange;
  Set<String> _symptomTags = {};
  bool _isNoteExpanded = false;

  @override
  void initState() {
    super.initState();
    _amount = 1;
    _unit = widget.action.defaultUnit;
    final initial = widget.initialDate ?? DateTime.now();
    final now = DateTime.now();
    _createdAt = DateTime(
      initial.year,
      initial.month,
      initial.day,
      now.hour,
      now.minute,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = _unitOptionsFor(widget.action);
    if (!units.contains(_unit)) {
      _unit = units.first;
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '记录 ${widget.action.name}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('记录日期'),
                subtitle: Text(_formatDate(_createdAt)),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _createdAt,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      locale: const Locale('zh', 'CN'),
                    );
                    if (picked != null) {
                      setState(() {
                        _createdAt = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          _createdAt.hour,
                          _createdAt.minute,
                        );
                      });
                    }
                  },
                  child: const Text('选择'),
                ),
              ),
              const SizedBox(height: 16),
              Text('完成了多少？', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final quick in _quickAmountsFor(widget.action))
                    ChoiceChip(
                      key: ValueKey(
                          'rehab-quick-amount-${quick.amount}-${quick.unit}'),
                      label: Text(quick.label),
                      selected: _formatAmount(_amount) == quick.amount &&
                          _unit == quick.unit,
                      onSelected: (_) {
                        setState(() {
                          _amount = double.tryParse(quick.amount) ?? _amount;
                          _unit = quick.unit;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _AmountStepper(
                amount: _amount,
                unit: _unit,
                onDecrease: () => setState(() {
                  _amount =
                      (_amount - _stepForUnit(_unit)).clamp(0, 999).toDouble();
                }),
                onIncrease: () => setState(() {
                  _amount =
                      (_amount + _stepForUnit(_unit)).clamp(0, 999).toDouble();
                }),
              ),
              const SizedBox(height: 12),
              Text('单位', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                key: const ValueKey('rehab-unit-options'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final unit in units)
                    ChoiceChip(
                      label: Text(unit),
                      selected: _unit == unit,
                      onSelected: (_) => setState(() => _unit = unit),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('做完感觉？', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reaction in RehabReaction.values)
                    ChoiceChip(
                      avatar: Icon(_reactionIcon(reaction), size: 18),
                      label: Text(reaction.label),
                      selected: _reaction == reaction,
                      selectedColor: _reactionColor(reaction).withValues(
                        alpha: 0.16,
                      ),
                      onSelected: (_) => setState(() => _reaction = reaction),
                    ),
                ],
              ),
              if (_reaction == RehabReaction.muchWorse) ...[
                const SizedBox(height: 10),
                const Card(
                  color: Color(0xFFFFF1F0),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('建议减少量、暂停观察，必要时咨询医生或康复师。'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text('症状标签（可选）', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _symptomTagOptions)
                    FilterChip(
                      label: Text(tag),
                      selected: _symptomTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          _symptomTags = {..._symptomTags};
                          selected
                              ? _symptomTags.add(tag)
                              : _symptomTags.remove(tag);
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _OptionalNoteField(
                controller: _noteController,
                isExpanded: _isNoteExpanded,
                onToggle: () {
                  setState(() => _isNoteExpanded = !_isNoteExpanded);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('rehab-log-save-button'),
                    onPressed: () {
                      Navigator.of(context).pop(
                        _RehabLogDraft(
                          amount: _formatAmount(_amount),
                          unit: _unit,
                          reaction: _reaction,
                          symptomTags: _symptomTags.toList(),
                          note: _noteController.text,
                          createdAt: _createdAt,
                        ),
                      );
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountStepper extends StatelessWidget {
  const _AmountStepper({
    required this.amount,
    required this.unit,
    required this.onDecrease,
    required this.onIncrease,
  });

  final double amount;
  final String unit;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('rehab-amount-decrease'),
              onPressed: onDecrease,
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: '减少完成量',
            ),
            Expanded(
              child: Text(
                '${_formatAmount(amount)} $unit',
                key: const ValueKey('rehab-amount-stepper-value'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            IconButton(
              key: const ValueKey('rehab-amount-increase'),
              onPressed: onIncrease,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: '增加完成量',
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionalNoteField extends StatelessWidget {
  const _OptionalNoteField({
    required this.controller,
    required this.isExpanded,
    required this.onToggle,
  });

  final TextEditingController controller;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          key: const ValueKey('optional-note-toggle'),
          onPressed: onToggle,
          icon: Icon(isExpanded ? Icons.expand_less : Icons.note_add_outlined),
          label: const Text('添加备注（可选）'),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('optional-note-field'),
            controller: controller,
            decoration: const InputDecoration(labelText: '备注（可选）'),
            maxLines: 2,
          ),
        ],
      ],
    );
  }
}

class DailyRecoveryNoteSheet extends StatefulWidget {
  const DailyRecoveryNoteSheet({this.note, super.key});

  final DailyRecoveryNote? note;

  @override
  State<DailyRecoveryNoteSheet> createState() => _DailyRecoveryNoteSheetState();
}

class _DailyRecoveryNoteSheetState extends State<DailyRecoveryNoteSheet> {
  static const _tagOptions = ['腰酸', '腰痛', '腿麻', '脚背刺痛', '疲劳'];

  final _noteController = TextEditingController();
  late OverallFeeling _overallFeeling;
  late int _backPainScore;
  late int _legSymptomScore;
  late int _fatigueScore;
  late Set<String> _tags;
  bool _isNoteExpanded = false;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _overallFeeling = note?.overallFeeling ?? OverallFeeling.same;
    _backPainScore = note?.backPainScore ?? 0;
    _legSymptomScore = note?.legSymptomScore ?? 0;
    _fatigueScore = note?.fatigueScore ?? 0;
    _tags = {...?note?.tags};
    _noteController.text = note?.note ?? '';
    _isNoteExpanded = _noteController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '每日康复小结',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              Text('整体感觉', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<OverallFeeling>(
                key: const ValueKey('daily-feeling-segmented'),
                segments: const [
                  ButtonSegment(
                    value: OverallFeeling.better,
                    label: Text('好一点'),
                  ),
                  ButtonSegment(
                    value: OverallFeeling.same,
                    label: Text('差不多'),
                  ),
                  ButtonSegment(
                    value: OverallFeeling.slightlyWorse,
                    label: Text('有点加重'),
                  ),
                ],
                selected: {_overallFeeling},
                onSelectionChanged: (selected) {
                  setState(() => _overallFeeling = selected.single);
                },
              ),
              const SizedBox(height: 16),
              _ScoreSlider(
                key: const ValueKey('daily-back-pain-slider-row'),
                label: '腰部不适',
                value: _backPainScore,
                sliderKey: const ValueKey('daily-back-pain-slider'),
                onChanged: (value) => setState(() => _backPainScore = value),
              ),
              _ScoreSlider(
                key: const ValueKey('daily-leg-symptom-slider-row'),
                label: '腿部症状',
                value: _legSymptomScore,
                sliderKey: const ValueKey('daily-leg-symptom-slider'),
                onChanged: (value) => setState(() => _legSymptomScore = value),
              ),
              _ScoreSlider(
                key: const ValueKey('daily-fatigue-slider-row'),
                label: '疲劳',
                value: _fatigueScore,
                sliderKey: const ValueKey('daily-fatigue-slider'),
                onChanged: (value) => setState(() => _fatigueScore = value),
              ),
              const SizedBox(height: 12),
              Text('症状标签（可选）', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _tagOptions)
                    FilterChip(
                      label: Text(tag),
                      selected: _tags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          _tags = {..._tags};
                          selected ? _tags.add(tag) : _tags.remove(tag);
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _OptionalNoteField(
                controller: _noteController,
                isExpanded: _isNoteExpanded,
                onToggle: () {
                  setState(() => _isNoteExpanded = !_isNoteExpanded);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _DailyRecoveryNoteDraft(
                          overallFeeling: _overallFeeling,
                          backPainScore: _backPainScore,
                          legSymptomScore: _legSymptomScore,
                          fatigueScore: _fatigueScore,
                          tags: _tags.toList(),
                          note: _noteController.text,
                        ),
                      );
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreSlider extends StatelessWidget {
  const _ScoreSlider({
    required this.label,
    required this.value,
    required this.sliderKey,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int value;
  final Key sliderKey;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(
              '$value / 10',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        Slider(
          key: sliderKey,
          min: 0,
          max: 10,
          divisions: 10,
          value: value.toDouble(),
          label: value.toString(),
          onChanged: (next) => onChanged(next.round()),
        ),
      ],
    );
  }
}

class _DailyRecoveryNoteDraft {
  const _DailyRecoveryNoteDraft({
    required this.overallFeeling,
    required this.backPainScore,
    required this.legSymptomScore,
    required this.fatigueScore,
    required this.tags,
    required this.note,
  });

  final OverallFeeling overallFeeling;
  final int backPainScore;
  final int legSymptomScore;
  final int fatigueScore;
  final List<String> tags;
  final String note;
}

typedef _RehabLogDraft = RehabLogDraft;

class RehabLogDraft {
  const RehabLogDraft({
    required this.amount,
    required this.unit,
    required this.reaction,
    required this.symptomTags,
    required this.note,
    required this.createdAt,
  });

  final String amount;
  final String unit;
  final RehabReaction reaction;
  final List<String> symptomTags;
  final String note;
  final DateTime createdAt;
}
