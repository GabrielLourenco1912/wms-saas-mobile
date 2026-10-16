# Integração do aplicativo mobile com a API WMS

Este documento descreve o consumo implementado no submódulo mobile. O contrato de referência é [API_CLIENTS.md](../../wms-saas-backend/docs/API_CLIENTS.md), publicado no commit `806b14b` do backend. Os controllers/DTOs do backend prevalecem para regras e campos completos. Esta adaptação não altera o backend.

## Configuração e sessão

`API_BASE_URL` define a origem da API, sem acrescentar `/api`. A configuração fica em [app_config.dart](../lib/src/core/config/app_config.dart). O padrão Android é `http://10.0.2.2:8080`; nas outras plataformas, `http://localhost:8080`. Para aparelho físico, use um endereço de rede acessível. HTTP local está liberado nos builds Android debug/profile; produção deve usar HTTPS.

O Dio de autenticação envia `X-Client-Type: MOBILE`. O Dio operacional acrescenta `Authorization: Bearer <token>`. Não há tokens fixos ou credenciais de demonstração.

| Fluxo | Chamadas | Comportamento do aplicativo |
| --- | --- | --- |
| Entrada | `POST /api/auth/login` → **202**; `POST /api/auth/challenge/verify` → **200** | Guarda o desafio na tela, solicita código de seis dígitos e preserva zeros iniciais. Apenas a confirmação retorna tokens. |
| Identidade e permissões | `GET /api/users/me` | Carrega nome, e-mail, perfil, situação e permissões; não deduz permissões do JWT ou de um perfil fixo. |
| Renovação | `POST /api/auth/refresh` com `{"refreshToken":"..."}` | Substitui ambos os tokens e suas expirações no armazenamento seguro. Chamadas concorrentes compartilham a renovação. |
| Saída | `POST /api/auth/logout` com o refresh atual | Remove os dados locais mesmo se o servidor estiver indisponível; nesse caso, a revogação remota não é confirmada. |
| Recuperação | `POST /api/auth/forgot-password` → **202**; `POST /api/auth/reset-password` → **200** | Solicita código, nova senha e confirmação; retorna ao login após redefinir. Não usa o endpoint de confirmação de login para redefinir a senha. |

Um 401 de uma rota protegida permite renovar e repetir a chamada uma única vez. Falha de rede na renovação preserva as credenciais para nova tentativa; rejeição definitiva invalida a sessão. Um 403 não dispara refresh. A requisição conserva a identidade e a revisão local da sessão: uma chamada antiga não é repetida com os tokens de outra conta ou de um novo login.

As rotas públicas da interface são `/login` e `/forgot-password`. Não há formulário de cadastro público. A tela de perfil permite atualizar as permissões com uma nova consulta a `/api/users/me`.

## Páginas, pesquisa e seletores

O envelope é `ApiEnvelope<T>`; o conteúdo útil fica em `data`. Uma página é `ApiPage<T>`, com `content`, `page`, `size`, `totalElements`, `totalPages`, `first` e `last`.

```http
GET /api/receipts?page=0&size=20&q=NF-123&status=PENDENTE
GET /api/lookups/positions?page=0&size=5&q=DOC&warehouseId=<id>
```

As listas usam pesquisa na API com debounce, retorno à página zero ao mudar filtros e navegação entre páginas. O repositório permite tamanho configurável, usando 20 por padrão. Embalagens usam `/api/search/product-packages`. Os seletores usam `/api/lookups/{recurso}` com cinco opções por página e preservam os filtros de escopo, como produto, armazém e situação. Não carregam todo o cadastro para filtrá-lo no aparelho.

Os principais seletores são `products`/`product-packages` (`PRODUCT_VIEW`), `positions` (`WAREHOUSE_VIEW`), `stock`/`lpns` (`STOCK_VIEW`), `orders` (`ORDER_VIEW`) e `users` (`USER_VIEW`). A permissão de executar um fluxo não concede automaticamente consulta aos cadastros auxiliares.

## Telas, endpoints e permissões

Todos os caminhos abaixo começam na origem configurada. Os parâmetros entre chaves representam IDs retornados pela API. A permissão de consulta e a de execução são verificadas separadamente; estados do documento, responsabilidade da tarefa e leituras físicas também condicionam as ações.

| Tela/ação | Endpoints consumidos | Permissões principais |
| --- | --- | --- |
| Painel e catálogo de operações | `GET /api/{recurso}?status=...&page=0&size=1` para as filas visíveis | Permissão `*_VIEW` de cada módulo. O painel usa `totalElements` do servidor; falhas não viram zero ou estimativas. |
| Recebimento: fila e detalhe | `GET /api/receipts`; `GET /api/receipts/{id}` | `RECEIPT_VIEW` |
| Confirmar recebimento | `POST /api/receipts/{id}/confirm` | `RECEIPT_EXECUTE`; `PRODUCT_VIEW`/`WAREHOUSE_VIEW` para as consultas auxiliares utilizadas |
| Armazenagem: fila e detalhe | `GET /api/putaway-tasks`; `GET /api/putaway-tasks/{id}` | `PUTAWAY_VIEW` |
| Iniciar/concluir armazenagem | `POST /api/putaway-tasks/{id}/start`; `POST /api/putaway-tasks/{id}/complete` | `PUTAWAY_EXECUTE` |
| Separação: fila e detalhe | `GET /api/picking-tasks`; `GET /api/picking-tasks/{id}` | `PICKING_VIEW` |
| Iniciar/concluir separação | `POST /api/picking-tasks/{id}/start`; `POST /api/picking-tasks/{id}/complete` | `PICKING_EXECUTE` |
| Informar falta física | `POST /api/picking-tasks/{id}/divergences` | `PICKING_REPORT_DIVERGENCE` |
| Autorizar quantidade excedente | `POST /api/tasks/{id}/authorize-excess` | `TASK_QUANTITY_OVERRIDE` |
| Expedição: fila e detalhe | `GET /api/shipments`; `GET /api/shipments/{id}` | `SHIPMENT_VIEW` |
| Preparar carga | `POST /api/shipments`; seletores de pedido, doca e LPN | `SHIPMENT_EXECUTE`, `ORDER_VIEW`, `WAREHOUSE_VIEW`, `STOCK_VIEW` |
| Conferir/despachar carga | `POST /api/shipments/{id}/confirm`; `POST /api/shipments/{id}/dispatch` | `SHIPMENT_EXECUTE` |
| Cancelar carga | `POST /api/shipments/{id}/cancel` | `ORDER_CANCEL` |
| Inventário: fila e detalhe | `GET /api/inventories`; `GET /api/inventories/{id}` | `INVENTORY_VIEW` |
| Abrir inventário | `POST /api/inventories` | `INVENTORY_EXECUTE`, `WAREHOUSE_VIEW`; selecionar outro responsável requer `USER_VIEW` |
| Registrar contagem ou mercadoria encontrada | `POST /api/inventories/{id}/counts` | `INVENTORY_EXECUTE`, responsável pelo inventário; descoberta usa `PRODUCT_VIEW` |
| Reconciliar/cancelar inventário | `POST /api/inventories/{id}/adjust`; `POST /api/inventories/{id}/cancel` | Ajuste: `INVENTORY_ADJUST`; cancelamento: responsável com `INVENTORY_EXECUTE` ou perfil com `INVENTORY_ADJUST`, conforme a API |
| Transferências: fila e detalhe | `GET /api/transfers`; `GET /api/transfers/{id}` | `TRANSFER_VIEW` |
| Criar/confirmar transferência | `POST /api/transfers`; `POST /api/transfers/{id}/confirm` | `TRANSFER_EXECUTE`; criação consulta estoque/LPNs e posições com `STOCK_VIEW`/`WAREHOUSE_VIEW` |
| Saldos e detalhe do estoque | `GET /api/stock`; `GET /api/stock/{id}` | `STOCK_VIEW` |
| Bloquear/desbloquear saldo | `POST /api/stock/{id}/block`; `POST /api/stock/{id}/unblock` | `STOCK_BLOCK` / `STOCK_UNBLOCK` |
| Bloqueios e liberação | `GET /api/stock-blocks`; `POST /api/stock-blocks/{id}/release` | Consulta: `STOCK_VIEW`; liberação: `STOCK_UNBLOCK` |
| Livro razão e detalhe | `GET /api/stock-transactions`; `GET /api/stock-transactions/{id}` | `AUDIT_VIEW`; consulta sem edição dos lançamentos |

O recebimento apresenta itens e confirmações da API, permitindo informar embalagem, quantidade, LPN, posição, lote e validade quando aplicáveis. O putaway exige a movimentação integral do LPN e a confirmação do endereço planejado. Picking diferencia conclusão da quantidade prevista, falta física e autorização gerencial de excesso. Expedição separa preparação, conferência e despacho. Inventário registra contagens, inclusive zero, antes da reconciliação. Transferências distinguem LPN integral e camada de estoque, com validação das leituras de origem/destino/produto.

O aplicativo não cria os cadastros administrativos, os pré-recebimentos, os pedidos de saída ou as ondas. Esses registros precisam ser preparados por outro cliente ou pela API para alimentar as filas operacionais.

## Segurança da operação e experiência de uso

- Botões e módulos dependem das permissões atuais. A validação definitiva permanece no servidor, incluindo estado, responsabilidade, saldo e vínculos.
- Formulários indicam os dados físicos a conferir, unidades e justificativas. Campos de leitura aceitam teclado e scanner HID; não há integração com câmera ou SDK específico de coletor.
- Consultas exibem carregamento, estado vazio, erro e nova tentativa. A atualização manual consulta novamente o servidor; o aplicativo não baixa estoque localmente por antecipação.
- Ações em andamento bloqueiam envios duplicados. A confirmação recebida atualiza o detalhe; falha ao atualizar uma consulta após sucesso deve ser tratada como falha da consulta, sem presumir nova execução do comando.
- Quantidades aceitam vírgula decimal na entrada e são normalizadas para o JSON. Os validadores limitam inteiros/casas decimais conforme o contrato e recusam valores que perderiam precisão no transporte numérico do dispositivo; não arredondam silenciosamente a quantidade do operador.
- Textos da autenticação explicam código, validade, recuperação e solicitação de acesso ao gestor. O perfil apresenta identidade real e permissões com descrições legíveis.

### Idempotência e interrupções

`OperationCommandRunner` gera uma chave por método, caminho e payload canônico. Repetições simultâneas do mesmo comando compartilham a chamada em andamento. A chave é enviada em `Idempotency-Key`; os comandos de picking e expedição recebem `idempotencyKey` no corpo, conforme seus DTOs.

Timeouts, falhas de rede, respostas 409 e erros de servidor conservam a chave para repetir **os mesmos dados**. Rejeições definitivas de validação/autorização encerram essa tentativa. Alterar o payload constitui outro comando; após uma resposta incerta, consulte o estado do documento antes de alterar ou enviar uma nova operação.

As chaves pendentes ficam **somente em memória** e são vinculadas à sessão do usuário. Fechar/reiniciar o aplicativo ou trocar de conta perde esse histórico. Nesses casos, consulte o servidor antes de repetir a ação. Não existe fila persistente, sincronização offline ou reenvio automático ao recuperar a conexão.

## Verificação e limites da entrega

Os testes em `test/auth`, `test/network` e `test/operations` verificam contratos usando providers e adaptadores HTTP substituídos. Cobrem login em duas etapas, recuperação, router real, renovação concorrente, isolamento de sessões, paginação/dropdowns, fluxos operacionais e idempotência. Os testes de quantidade incluem limites de precisão.

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Validação atualizada em 16/10/2026, com Flutter 3.41.9 e Dart 3.11.5:

- Formatação: nenhum arquivo pendente.
- `flutter analyze --no-pub`: nenhuma ocorrência.
- `flutter test --no-pub`: **66 testes aprovados**.
- `flutter build apk --debug --no-pub`: APK Android gerado em `build/app/outputs/flutter-apk/app-debug.apk`.
- Layout verificado em teste com largura de 320 pixels e escala de texto de 1,6 no painel/listas e 2 no acesso e na seção Sobre; capturas de 390 × 844 também inspecionadas com dados de teste.
- Tema Manrope/DM Mono, marca, autoria e recursos nativos aplicados conforme [guia de identidade visual](IDENTIDADE_VISUAL.md), preservando os contratos acima.

 A existência dos testes não representa homologação com um armazém, backend real, servidor SMTP ou scanner físico. A conferência em dispositivo e a homologação integrada permanecem necessárias, assim como validar conectividade/permissões de rede nas plataformas de distribuição.

O arquivo legado `frontend-authentication-contract.txt` foi preservado, mas está obsoleto: descreve login com token imediato, cadastro público e transporte antigo do refresh. Para desenvolvimento e novas telas, use esta documentação e o guia atual do backend.
