# WMS SaaS Mobile

Aplicativo Flutter para executar operações de armazém no backend WMS: recebimento, armazenagem, separação, expedição, inventário, transferências e consulta de estoque/auditoria. Os dados e os totais do painel vêm da API; o aplicativo não usa o antigo ambiente de demonstração em memória.

A documentação de integração está em [docs/INTEGRACAO_API.md](docs/INTEGRACAO_API.md), com a relação entre telas, endpoints, permissões e limites desta entrega. A identidade visual, os ícones nativos e sua manutenção estão em [docs/IDENTIDADE_VISUAL.md](docs/IDENTIDADE_VISUAL.md). O contrato completo é o [guia dos clientes do backend](../wms-saas-backend/docs/API_CLIENTS.md), publicado no commit `806b14b` do backend.

## Executar

Use uma versão de Flutter compatível com o SDK Dart definido em [pubspec.yaml](pubspec.yaml). O backend deve estar acessível, com o serviço de e-mail configurado e uma conta criada pelo gestor.

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Sem `API_BASE_URL`, o padrão é `http://10.0.2.2:8080` no Android e `http://localhost:8080` nas demais plataformas. `10.0.2.2` acessa o computador host pelo emulador Android. Em aparelho físico, informe o endereço do servidor acessível pela rede do aparelho; `localhost` representa o próprio dispositivo.

Os manifests Android de debug/profile permitem HTTP para desenvolvimento. Use HTTPS na configuração de produção. Não coloque credenciais ou tokens em `--dart-define`.

## Acesso e operação

- O login envia e-mail/senha e recebe um desafio. O acesso só é liberado após confirmar o código recebido por e-mail e carregar o perfil em `/api/users/me`.
- Não existe cadastro público no aplicativo. A criação de contas é administrativa; a recuperação de senha está disponível na tela de entrada.
- Access token e refresh token ficam no armazenamento seguro. As renovações simultâneas compartilham uma única chamada; um 401 protegido permite uma repetição, enquanto um 403 informa falta de permissão.
- Listas usam páginas de 20 registros, pesquisa e filtros por situação. Seletores pesquisam opções em páginas de cinco.
- As leituras físicas aceitam digitação, scanners que funcionem como teclado (HID) e captura por câmera nos campos de SKU, LPN e posição. A câmera preenche o campo; a API valida a confirmação. Não há execução de operações sem conexão.
- Após uma resposta incerta, repita somente a mesma operação e os mesmos dados. A chave de idempotência fica em memória enquanto a sessão permanece ativa. Após reiniciar o aplicativo, consulte o estado no servidor antes de repetir uma operação pendente.

## Organização

A estrutura permanece orientada a funcionalidades: `app` reúne navegação/tema; `core` reúne rede, configuração e armazenamento; `features/auth` mantém sessão e identidade; `features/operations` reúne os fluxos operacionais, repositório paginado e comandos idempotentes; `features/profile` apresenta os dados da conta e atualiza permissões.

Riverpod coordena dependências e estado, GoRouter protege a navegação, Dio transporta os contratos HTTP e `flutter_secure_storage` mantém os tokens. Os testes substituem providers e adaptadores HTTP, sem habilitar um modo mock de produção.

## Verificação

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Há testes de autenticação, concorrência do refresh, navegação real, paginação, seletores, contratos operacionais, precisão de quantidades e repetição idempotente. Esses testes não substituem a homologação com o backend em execução, entrega real de e-mail e dispositivos de operação. Validação desta entrega: análise estática sem ocorrências, 66 testes aprovados e APK Android debug compilado. Os detalhes estão no guia de integração.

O arquivo `frontend-authentication-contract.txt` foi preservado como histórico e está **obsoleto**: descreve cadastro público e login direto que não representam a API atual. Use os guias Markdown citados acima.
