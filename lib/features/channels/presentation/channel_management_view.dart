import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../domain/channel.dart';
import 'providers/channel_providers.dart';

class ChannelManagementView extends ConsumerWidget {
  const ChannelManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(allChannelsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '停用後不會出現在新交易中，歷史紀錄仍會保留。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const Key('addChannelButton'),
              onPressed: () => _openEditor(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('新增'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        channels.when(
          data: (items) {
            final active = items.where((item) => item.isActive).toList();
            final inactive = items.where((item) => !item.isActive).toList();
            if (items.isEmpty) {
              return AppEmptyView(
                title: '還沒有購物管道',
                message: '新增購物管道，記錄每筆消費是在哪裡完成的。',
                actionLabel: '新增購物管道',
                onAction: () => _openEditor(context, ref),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Column(
                    children: [
                      for (var index = 0; index < active.length; index++) ...[
                        if (index > 0) const Divider(height: 1, indent: 64),
                        _ChannelTile(
                          channel: active[index],
                          onEdit: () =>
                              _openEditor(context, ref, channel: active[index]),
                          onSetActive: () =>
                              _setActive(context, ref, active[index], false),
                        ),
                      ],
                    ],
                  ),
                ),
                if (inactive.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ExpansionTile(
                    key: const Key('inactiveChannelsSection'),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text('已停用的管道（${inactive.length}）'),
                    children: [
                      Card(
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < inactive.length;
                              index++
                            ) ...[
                              if (index > 0)
                                const Divider(height: 1, indent: 64),
                              _ChannelTile(
                                channel: inactive[index],
                                onEdit: () => _openEditor(
                                  context,
                                  ref,
                                  channel: inactive[index],
                                ),
                                onSetActive: () => _setActive(
                                  context,
                                  ref,
                                  inactive[index],
                                  true,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
          loading: () => const AppLoadingView(message: '正在載入購物管道'),
          error: (error, _) => AppErrorView(
            message: '購物管道載入失敗：$error',
            onRetry: () => ref.invalidate(allChannelsProvider),
          ),
        ),
      ],
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    ShoppingChannel? channel,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ChannelEditorSheet(channel: channel),
    );
    if (saved != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(channel == null ? '購物管道已新增' : '購物管道已更新')),
    );
  }

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    ShoppingChannel channel,
    bool active,
  ) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('停用「${channel.name}」？'),
          content: const Text('停用後，新交易將無法選擇這個管道，但原有交易與統計資料不會被刪除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('停用'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await ref
          .read(channelRepositoryProvider)
          .setChannelActive(channel.id, active);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(active ? '購物管道已恢復使用' : '購物管道已停用')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('操作失敗：$error'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.onEdit,
    required this.onSetActive,
  });

  final ShoppingChannel channel;
  final VoidCallback onEdit;
  final VoidCallback onSetActive;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: channel.isActive ? 1 : 0.55,
    child: ListTile(
      key: Key('channel-${channel.id}'),
      leading: const CircleAvatar(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.ink,
        child: Icon(Icons.storefront_outlined),
      ),
      title: Text(channel.name),
      subtitle: Text(channel.isActive ? '使用中' : '已停用・歷史資料保留'),
      trailing: channel.isActive
          ? PopupMenuButton<String>(
              key: Key('channelMenu-${channel.id}'),
              onSelected: (action) =>
                  action == 'edit' ? onEdit() : onSetActive(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('修改名稱')),
                PopupMenuItem(value: 'active', child: Text('停用')),
              ],
            )
          : SizedBox(
              width: 132,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    key: Key('editInactiveChannel-${channel.id}'),
                    tooltip: '修改名稱',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  TextButton(
                    key: Key('restoreChannel-${channel.id}'),
                    onPressed: onSetActive,
                    child: const Text('恢復'),
                  ),
                ],
              ),
            ),
    ),
  );
}

class _ChannelEditorSheet extends ConsumerStatefulWidget {
  const _ChannelEditorSheet({this.channel});

  final ShoppingChannel? channel;

  @override
  ConsumerState<_ChannelEditorSheet> createState() =>
      _ChannelEditorSheetState();
}

class _ChannelEditorSheetState extends ConsumerState<_ChannelEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.channel?.name ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.channel == null ? '新增購物管道' : '修改購物管道',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const Key('channelNameField'),
            controller: _controller,
            autofocus: true,
            maxLength: 40,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: '管道名稱',
              hintText: '例如：外送平台',
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? '請輸入購物管道名稱' : null,
            onFieldSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.expense)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('saveChannelButton'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(widget.channel == null ? '新增' : '儲存'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(channelRepositoryProvider);
      final input = ShoppingChannelInput(name: _controller.text);
      if (widget.channel == null) {
        await repository.createChannel(input);
      } else {
        await repository.updateChannel(widget.channel!.id, input);
      }
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '儲存失敗：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
