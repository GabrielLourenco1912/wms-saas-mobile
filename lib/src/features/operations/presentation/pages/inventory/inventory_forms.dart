import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/application/auth_controller.dart';
import '../../../application/operation_command.dart';
import '../../../data/warehouse_repository.dart';
import '../../widgets/api_operation_widgets.dart';
import '../outbound/operation_flow_widgets.dart';

class CreateInventoryPage extends ConsumerStatefulWidget {
  const CreateInventoryPage({super.key});
  @override
  ConsumerState<CreateInventoryPage> createState() =>
      _CreateInventoryPageState();
}

class _CreateInventoryPageState extends ConsumerState<CreateInventoryPage> {
  final _positionCode = TextEditingController();
  LookupOption? _position;
  LookupOption? _responsible;

  @override
  void dispose() {
    _positionCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).value;
    return OperationCommandPage(
      title: 'Abrir inventário',
      description:
          'Escolha a posição e leia seu código físico. A abertura cria um snapshot e congela a posição para movimentações. Reservas e tarefas ativas precisam estar resolvidas. O responsável padrão é você.',
      submitLabel: 'Abrir inventário e congelar posição',
      fields: (busy) => [
        ApiLookupField(
          resource: 'positions',
          label: 'Posição para contagem',
          value: _position,
          enabled: !busy,
          isRequired: true,
          filters: const {'active': 'true'},
          onChanged: (value) => setState(() {
            _position = value;
          }),
        ),
        const SizedBox(height: 14),
        operationField(
          label: 'Código físico da posição lido',
          scan: true,
          technical: true,
          controller: _positionCode,
          enabled: !busy,
          maxLength: 50,
        ),
        if (auth?.can('USER_VIEW') ?? false) ...[
          ApiLookupField(
            resource: 'users',
            label: 'Responsável (opcional)',
            value: _responsible,
            enabled: !busy,
            helperText:
                'Se não selecionar, você será o responsável. O servidor valida a permissão de inventário.',
            filters: const {'status': 'ACTIVE'},
            onChanged: (value) => setState(() {
              _responsible = value;
            }),
          ),
          const SizedBox(height: 14),
        ],
      ],
      submit: () => ref
          .read(operationCommandProvider)
          .run(
            '/api/inventories',
            body: {
              'positionId': _position!.id,
              'scannedPositionCode': _positionCode.text.trim(),
              if (_responsible != null) 'responsibleUserId': _responsible!.id,
            },
          ),
      successMessage: (_) =>
          'Inventário aberto. Atualize a lista e abra o inventário para contar os itens.',
    );
  }
}

class InventoryCountPage extends ConsumerStatefulWidget {
  const InventoryCountPage({super.key, required this.inventory, this.item});
  final JsonMap inventory;
  final JsonMap? item;
  @override
  ConsumerState<InventoryCountPage> createState() => _InventoryCountPageState();
}

class _InventoryCountPageState extends ConsumerState<InventoryCountPage> {
  final _positionCode = TextEditingController();
  final _lpn = TextEditingController();
  final _productCode = TextEditingController();
  final _quantity = TextEditingController();
  final _lot = TextEditingController();
  final _expiry = TextEditingController();
  LookupOption? _product;
  JsonMap? _productDetails;
  bool _loadingProduct = false;
  String? _productError;
  int _productGeneration = 0;

  @override
  void dispose() {
    for (final controller in [
      _positionCode,
      _lpn,
      _productCode,
      _quantity,
      _lot,
      _expiry,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectProduct(LookupOption? value) async {
    final generation = ++_productGeneration;
    setState(() {
      _product = value;
      _productDetails = null;
      _productError = null;
      _loadingProduct = value != null;
      _lot.clear();
      _expiry.clear();
    });
    if (value == null) return;
    try {
      final product = await ref
          .read(warehouseRepositoryProvider)
          .detail('products', value.id);
      if (mounted && generation == _productGeneration) {
        setState(() {
          _productDetails = product;
          _loadingProduct = false;
        });
      }
    } catch (error) {
      if (mounted && generation == _productGeneration) {
        setState(() {
          _productError = '$error';
          _loadingProduct = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.item ?? const <String, dynamic>{};
    final isNew = widget.item == null;
    return OperationCommandPage(
      title: isNew ? 'Mercadoria encontrada' : 'Contagem física',
      description: isNew
          ? 'Registre um produto e LPN encontrados que não constam no snapshot. Informe lote e validade conforme o cadastro do produto. A quantidade será aplicada somente na reconciliação.'
          : 'Produto esperado: ${existing['sku']}. LPN esperado: ${existing['lpnCode']}. Leia os códigos físicos e informe sua contagem, inclusive zero. A contagem não altera o estoque até a reconciliação.',
      submitLabel: isNew
          ? 'Registrar achado e contagem'
          : 'Registrar contagem física',
      fields: (busy) => [
        if (isNew) ...[
          ApiLookupField(
            resource: 'products',
            label: 'Produto encontrado',
            value: _product,
            enabled: !busy,
            isRequired: true,
            filters: const {'active': 'true'},
            onChanged: _selectProduct,
          ),
          const SizedBox(height: 14),
          if (_loadingProduct) const LinearProgressIndicator(),
          if (_productError != null) ...[
            Text(
              _productError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: busy ? null : () => _selectProduct(_product),
              child: const Text('Recarregar produto'),
            ),
          ],
          if (_productDetails != null)
            Text(
              'Rastreabilidade: lote ${_productDetails!['lotControlled'] == true ? 'obrigatório' : 'opcional'} · validade ${_productDetails!['expiryControlled'] == true ? 'obrigatória' : 'opcional'}',
            ),
          const SizedBox(height: 14),
        ],
        operationField(
          label: 'Código físico da posição lido',
          scan: true,
          technical: true,
          controller: _positionCode,
          enabled: !busy,
          maxLength: 50,
        ),
        operationField(
          label: 'LPN lido',
          scan: true,
          technical: true,
          controller: _lpn,
          enabled: !busy,
        ),
        operationField(
          label: 'SKU do produto lido',
          scan: true,
          technical: true,
          controller: _productCode,
          enabled: !busy,
        ),
        operationField(
          label: 'Quantidade física em unidade base',
          controller: _quantity,
          enabled: !busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) =>
              validateOperationQuantity(value, allowZero: true),
        ),
        if (isNew) ...[
          operationField(
            label: 'Lote',
            technical: true,
            controller: _lot,
            enabled: !busy,
            isRequired: _productDetails?['lotControlled'] == true,
          ),
          operationField(
            label: 'Validade (AAAA-MM-DD)',
            technical: true,
            controller: _expiry,
            enabled: !busy,
            isRequired: _productDetails?['expiryControlled'] == true,
            keyboardType: TextInputType.datetime,
            validator: (value) {
              if ((value?.trim().isEmpty ?? true) &&
                  _productDetails?['expiryControlled'] == true) {
                return 'Informe a validade do produto.';
              }
              return validateInventoryDate(value);
            },
          ),
        ] else ...[
          if (existing['lot'] != null)
            Text('Lote do snapshot: ${existing['lot']}'),
          if (existing['expiryDate'] != null)
            Text('Validade do snapshot: ${existing['expiryDate']}'),
        ],
      ],
      submit: () async {
        if (isNew &&
            (_loadingProduct ||
                _productDetails == null ||
                _productError != null)) {
          throw StateError('Carregue o produto antes de registrar o achado.');
        }
        final line = <String, dynamic>{
          if (isNew)
            'productId': _product!.id
          else
            'inventoryItemId': existing['id'],
          'lpnCode': _lpn.text.trim(),
          'scannedProductCode': _productCode.text.trim(),
          'countedQuantity': operationQuantity(_quantity.text),
          if (isNew && _lot.text.trim().isNotEmpty) 'lot': _lot.text.trim(),
          if (isNew && _expiry.text.trim().isNotEmpty)
            'expiryDate': _expiry.text.trim(),
        };
        return ref
            .read(operationCommandProvider)
            .run(
              '/api/inventories/${widget.inventory['id']}/counts',
              body: {
                'scannedPositionCode': _positionCode.text.trim(),
                'items': [line],
              },
            );
      },
    );
  }
}

String? validateInventoryDate(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return 'Use o formato AAAA-MM-DD.';
  }
  final date = DateTime.tryParse(text);
  return date == null || date.toIso8601String().substring(0, 10) != text
      ? 'Informe uma data válida.'
      : null;
}

class InventoryClosePage extends ConsumerStatefulWidget {
  const InventoryClosePage({
    super.key,
    required this.inventory,
    this.cancel = false,
  });
  final JsonMap inventory;
  final bool cancel;
  @override
  ConsumerState<InventoryClosePage> createState() => _InventoryClosePageState();
}

class _InventoryClosePageState extends ConsumerState<InventoryClosePage> {
  final _positionCode = TextEditingController();
  final _reason = TextEditingController();
  @override
  void dispose() {
    _positionCode.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OperationCommandPage(
    title: widget.cancel ? 'Cancelar inventário' : 'Reconciliar inventário',
    description: widget.cancel
        ? 'O inventário será cancelado e a posição liberada. O snapshot e as contagens ficam preservados; o saldo não será ajustado.'
        : 'O servidor aplicará as diferenças entre o snapshot e as contagens, registrará os movimentos de ajuste e encerrará o inventário. Confira todas as linhas antes de confirmar.',
    submitLabel: widget.cancel
        ? 'Confirmar cancelamento'
        : 'Aplicar ajustes e encerrar',
    fields: (busy) => [
      operationField(
        label: 'Código físico da posição lido',
        scan: true,
        technical: true,
        controller: _positionCode,
        enabled: !busy,
        maxLength: 50,
      ),
      if (!widget.cancel)
        operationField(
          label: 'Justificativa da reconciliação',
          controller: _reason,
          enabled: !busy,
          maxLength: 255,
        ),
    ],
    submit: () => ref
        .read(operationCommandProvider)
        .run(
          '/api/inventories/${widget.inventory['id']}/${widget.cancel ? 'cancel' : 'adjust'}',
          body: {
            'scannedPositionCode': _positionCode.text.trim(),
            if (!widget.cancel) 'reason': _reason.text.trim(),
          },
        ),
  );
}
