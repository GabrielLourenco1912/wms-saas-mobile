# WMS SaaS Mobile

Aplicativo Flutter para operação mobile de um WMS SaaS, com autenticação baseada no contrato em `frontend-authentication-contract.txt`.

## Arquitetura

A base usa uma arquitetura feature-first com camadas inspiradas em Clean Architecture:

- `core`: configuração, storage seguro, cliente HTTP, envelope/erros de API.
- `features/*/domain`: entidades e contratos de repositório.
- `features/*/data`: datasources, models e implementação de repositórios.
- `features/*/application`: estado e casos de uso coordenados por providers.
- `features/*/presentation`: páginas e widgets.
- `app`: tema, roteamento e composição global.

Essa arquitetura foi escolhida porque um WMS tende a crescer por módulos independentes, como recebimento, armazenagem, picking, expedição e inventário. Separar por feature reduz acoplamento e facilita evoluir cada fluxo sem transformar o app em uma camada única de telas e chamadas HTTP.

## Dependências principais

- `flutter_riverpod`: injeção de dependências e gerenciamento de estado testável, sem depender de `BuildContext`.
- `go_router`: roteamento declarativo com proteção de rotas autenticadas.
- `dio`: cliente HTTP robusto, com interceptors para `Authorization`, refresh token e retry de requisição.
- `flutter_secure_storage`: armazenamento local seguro para access token, refresh token e metadados da sessão.

## Autenticação

Fluxos implementados:

- Login em `POST /api/auth/login`.
- Cadastro em `POST /api/auth/register`.
- Restauração de sessão local.
- Refresh em `POST /api/auth/refresh`, enviando o access token no header e o refresh token no body, conforme o contrato.
- Logout local, limpando os tokens.
- Shell autenticado com painel, operação e perfil.

## Configuração da API

Por padrão, o app usa:

```bash
http://10.0.2.2:8080
```

Para mudar a URL da API:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Em emulador Android, `10.0.2.2` aponta para o host local da máquina.
O build debug/profile permite HTTP local para desenvolvimento. Em produção, use uma URL HTTPS.

## Qualidade

Comandos usados para validar a base:

```bash
flutter analyze
flutter test
```
