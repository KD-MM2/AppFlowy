import 'package:flutter/material.dart';

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/mobile/presentation/database/card/card.dart';
import 'package:appflowy/plugins/database/application/field/field_controller.dart';
import 'package:appflowy/plugins/database/application/row/row_cache.dart';
import 'package:appflowy/plugins/database/application/row/row_controller.dart';
import 'package:appflowy/plugins/database/grid/presentation/widgets/row/action.dart';
import 'package:appflowy/shared/af_image.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:collection/collection.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

import '../cell/card_cell_builder.dart';
import '../cell/card_cell_skeleton/card_cell.dart';

import 'card_bloc.dart';
import 'container/accessory.dart';
import 'container/card_container.dart';

/// Edit a database row with card style widget
class RowCard extends StatefulWidget {
  const RowCard({
    super.key,
    required this.fieldController,
    required this.rowMeta,
    required this.viewId,
    required this.isEditing,
    required this.rowCache,
    required this.cellBuilder,
    required this.onTap,
    required this.onStartEditing,
    required this.onEndEditing,
    required this.styleConfiguration,
    this.onShiftTap,
    this.groupingFieldId,
    this.groupId,
    this.userProfile,
    this.isCompact = false,
  });

  final FieldController fieldController;
  final RowMetaPB rowMeta;
  final String viewId;
  final String? groupingFieldId;
  final String? groupId;

  final bool isEditing;
  final RowCache rowCache;

  /// The [CardCellBuilder] is used to build the card cells.
  final CardCellBuilder cellBuilder;

  /// Called when the user taps on the card.
  final void Function(BuildContext context) onTap;

  final void Function(BuildContext context)? onShiftTap;

  /// Called when the user starts editing the card.
  final VoidCallback onStartEditing;

  /// Called when the user ends editing the card.
  final VoidCallback onEndEditing;

  final RowCardStyleConfiguration styleConfiguration;

  /// Specifically the token is used to handle requests to retrieve images
  /// from cloud storage, such as the card cover.
  final UserProfilePB? userProfile;

  /// Whether the card is in a narrow space.
  /// This is used to determine eg. the Cover height.
  final bool isCompact;

  @override
  State<RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<RowCard> {
  final popoverController = PopoverController();
  late final CardBloc _cardBloc;

  @override
  void initState() {
    super.initState();
    final rowController = RowController(
      viewId: widget.viewId,
      rowMeta: widget.rowMeta,
      rowCache: widget.rowCache,
    );

    _cardBloc = CardBloc(
      fieldController: widget.fieldController,
      viewId: widget.viewId,
      groupFieldId: widget.groupingFieldId,
      isEditing: widget.isEditing,
      rowController: rowController,
    )..add(const CardEvent.initial());
  }

  @override
  void didUpdateWidget(covariant oldWidget) {
    if (widget.isEditing != _cardBloc.state.isEditing) {
      _cardBloc.add(CardEvent.setIsEditing(widget.isEditing));
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _cardBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cardBloc,
      child: BlocConsumer<CardBloc, CardState>(
        listenWhen: (previous, current) =>
            previous.isEditing != current.isEditing,
        listener: (context, state) {
          if (!state.isEditing) {
            widget.onEndEditing();
          }
        },
        builder: (context, state) =>
            UniversalPlatform.isMobile ? _mobile(state) : _desktop(state),
      ),
    );
  }

  Widget _mobile(CardState state) {
    return GestureDetector(
      onTap: () => widget.onTap(context),
      behavior: HitTestBehavior.opaque,
      child: MobileCardContent(
        rowMeta: state.rowMeta,
        cellBuilder: widget.cellBuilder,
        styleConfiguration: widget.styleConfiguration,
        cells: state.cells,
      ),
    );
  }

  Widget _desktop(CardState state) {
    final accessories = widget.styleConfiguration.showAccessory
        ? const <CardAccessory>[
            EditCardAccessory(),
            MoreCardOptionsAccessory(),
          ]
        : null;
    return AppFlowyPopover(
      controller: popoverController,
      triggerActions: PopoverTriggerFlags.none,
      constraints: BoxConstraints.loose(const Size(140, 200)),
      direction: PopoverDirection.rightWithCenterAligned,
      popupBuilder: (_) => RowActionMenu.board(
        viewId: _cardBloc.viewId,
        rowId: _cardBloc.rowController.rowId,
        groupId: widget.groupId,
      ),
      child: RowCardContainer(
        buildAccessoryWhen: () => state.isEditing == false,
        accessories: accessories ?? [],
        openAccessory: _handleOpenAccessory,
        onTap: widget.onTap,
        onShiftTap: widget.onShiftTap,
        child: _CardContent(
          rowMeta: state.rowMeta,
          cellBuilder: widget.cellBuilder,
          styleConfiguration: widget.styleConfiguration,
          cells: state.cells,
          userProfile: widget.userProfile,
          isCompact: widget.isCompact,
        ),
      ),
    );
  }

  void _handleOpenAccessory(AccessoryType newAccessoryType) {
    switch (newAccessoryType) {
      case AccessoryType.edit:
        widget.onStartEditing();
        break;
      case AccessoryType.more:
        popoverController.show();
        break;
    }
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.rowMeta,
    required this.cellBuilder,
    required this.cells,
    required this.styleConfiguration,
    this.userProfile,
    this.isCompact = false,
  });

  final RowMetaPB rowMeta;
  final CardCellBuilder cellBuilder;
  final List<CellMeta> cells;
  final RowCardStyleConfiguration styleConfiguration;
  final UserProfilePB? userProfile;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        CardCover(
          cover: rowMeta.cover,
          userProfile: userProfile,
          isCompact: isCompact,
        ),
        Padding(
          padding: styleConfiguration.cardPadding,
          child: Column(
            children: _makeCells(context, rowMeta, cells),
          ),
        ),
      ],
    );
    return styleConfiguration.hoverStyle == null
        ? child
        : FlowyHover(
            style: styleConfiguration.hoverStyle,
            buildWhenOnHover: () => !context.read<CardBloc>().state.isEditing,
            child: child,
          );
  }

  List<Widget> _makeCells(
    BuildContext context,
    RowMetaPB rowMeta,
    List<CellMeta> cells,
  ) {
    return cells.mapIndexed((int index, CellMeta cellMeta) {
      EditableCardNotifier? cellNotifier;

      if (index == 0) {
        final bloc = context.read<CardBloc>();
        cellNotifier = EditableCardNotifier(isEditing: bloc.state.isEditing);
        cellNotifier.isCellEditing.addListener(() {
          final isEditing = cellNotifier!.isCellEditing.value;
          bloc.add(CardEvent.setIsEditing(isEditing));
        });
      }

      return cellBuilder.build(
        cellContext: cellMeta.cellContext(),
        cellNotifier: cellNotifier,
        styleMap: styleConfiguration.cellStyleMap,
        hasNotes: !rowMeta.isDocumentEmpty,
      );
    }).toList();
  }
}

class CardCover extends StatelessWidget {
  const CardCover({
    super.key,
    this.cover,
    this.userProfile,
    this.isCompact = false,
  });

  final RowCoverPB? cover;
  final UserProfilePB? userProfile;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (cover == null ||
        cover!.url.isEmpty ||
        cover!.uploadType == FileUploadTypePB.CloudFile &&
            userProfile == null) {
      return const SizedBox.shrink();
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
        color: Theme.of(context).cardColor,
      ),
      child: Row(
        children: [
          Expanded(
            child: AFImage(
              url: cover!.url,
              uploadType: cover!.uploadType,
              userProfile: userProfile,
              height: isCompact ? 50 : 100,
            ),
          ),
        ],
      ),
    );
  }
}

class EditCardAccessory extends StatelessWidget with CardAccessory {
  const EditCardAccessory({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: FlowySvg(
        FlowySvgs.edit_s,
        color: Theme.of(context).hintColor,
      ),
    );
  }

  @override
  AccessoryType get type => AccessoryType.edit;
}

class MoreCardOptionsAccessory extends StatelessWidget with CardAccessory {
  const MoreCardOptionsAccessory({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: FlowySvg(
        FlowySvgs.three_dots_s,
        color: Theme.of(context).hintColor,
      ),
    );
  }

  @override
  AccessoryType get type => AccessoryType.more;
}

class RowCardStyleConfiguration {
  const RowCardStyleConfiguration({
    required this.cellStyleMap,
    this.showAccessory = true,
    this.cardPadding = const EdgeInsets.all(8),
    this.hoverStyle,
  });

  final CardCellStyleMap cellStyleMap;
  final bool showAccessory;
  final EdgeInsets cardPadding;
  final HoverStyle? hoverStyle;
}
