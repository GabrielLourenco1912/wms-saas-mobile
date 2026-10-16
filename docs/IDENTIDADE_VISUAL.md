# Identidade visual no mobile

O WMS SaaS usa a direção **Precisão em movimento**, com a frase “Cada movimento, sob controle.” Floresta `#14251E`, verde operacional `#176B48`, lima `#D1F878` e papel `#F5F6F0` conectam o aplicativo ao painel web. A interface operacional é clara; splash e marca usam a base floresta. O aplicativo não oferece um tema escuro completo.

## Recursos e componentes

`lib/src/app/branding/brand_tokens.dart` centraliza cores, fontes, nomes, caminhos e a geometria do símbolo. `AppTheme.light` aplica esses papéis ao Material 3, com texto de 16, apoio de 14, botões de 16, alvos de pelo menos 48 e raios de 8/12/24. A escala de texto do sistema permanece ativa.

- `WmsBrandMark`: desenha o **W de percurso** com `CustomPainter`, a partir da mesma geometria vetorial usada no web. Não depende de fonte nem de pacote de SVG.
- `AuthorCredit`: preserva o PNG original do Monograma GL / 01 e compõe o nome em texto nativo. Aparece discretamente no acesso e na seção Sobre do perfil, separado da identidade da pessoa conectada.
- `BrandAboutCard`: reúne autoria, a ação explícita **Copiar link do portfólio** e as licenças do aplicativo. A cópia informa o resultado por mensagem; não abre uma tela de navegação embutida.
- `registerBrandLicenses`: registra as duas licenças SIL OFL no catálogo nativo de licenças.

Manrope variável e DM Mono 400/500 são empacotadas em `assets/branding/fonts/` e registradas no `pubspec.yaml`. Manrope serve à interface; DM Mono identifica códigos de acesso, leituras físicas e entradas numéricas operacionais. Não há download de fontes durante o build ou uso.

`assets/branding/provenance.json` registra os recursos copiados, suas origens e hashes. Os PNGs da assinatura permanecem idênticos aos arquivos fornecidos pelo autor.

## Integração com as plataformas

Android recebe ícones legados nas cinco densidades, camadas adaptativas a partir da API 26 e camada monocromática a partir da API 33. O splash usa o W lima sobre floresta, incluindo os recursos específicos da API 31. O nome exibido passa a ser **WMS SaaS**; application ID e assinatura de distribuição continuam sendo configurações próprias da aplicação.

O catálogo de ícones iOS mantém as 19 entradas esperadas pelo projeto. O storyboard de abertura usa fundo floresta e símbolo proporcional de 128 pontos. Os recursos foram preparados e seus arquivos verificados; compilação e inspeção em iOS exigem macOS/Xcode e não foram executadas no ambiente Linux desta entrega.

O alvo Flutter web também recebe favicon, ícones comuns/maskable, manifesto e título da marca. Ele é independente do painel de gestão Next.js.

## Atualizar a identidade

Na cópia completa de `TCC_WMS`, a especificação local está em `../docs-gerais/identidade-visual/`. Após alterar os tokens ou regenerar os recursos originais:

```bash
python3 scripts/sync_branding.py
python3 scripts/sync_branding.py --check
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

O script copia somente os recursos conhecidos, verifica a assinatura e gera os tokens Dart e os vetores Android. Alterações de paleta também exigem conferir as superfícies nativas no storyboard iOS, nos temas Android e no manifesto web. Não editar separadamente os PNGs de launcher.

Fontes, imagens, tokens e recursos nativos são versionados neste submódulo. O build não executa o script nem depende de `docs-gerais`. Não foram acrescentadas dependências Flutter nem alterados endpoints, sessão, permissões ou comandos operacionais.

## Verificação

Em 16/10/2026, com Flutter 3.41.9 e Dart 3.11.5: análise estática, 66 testes e APK Android debug aprovados. A cobertura inclui os fluxos existentes, painel/listas em tela estreita, acesso em 320 px com escala de texto 2 e cópia do portfólio na seção Sobre. Acesso, desafio, splash e Sobre também foram inspecionados por capturas com os componentes reais, fontes locais e dados fictícios, sem acesso à API. Essas verificações não representam execução em aparelho físico ou homologação em armazém.
