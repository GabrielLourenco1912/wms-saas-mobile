# Assinatura escolhida para o WMS

Etapa 3/5 · versão 1.0 · 16/10/2026.

**Seleção: Monograma GL, número 01, em português e nas variantes monocromáticas.**

A escolha utiliza a coleção disponibilizada pelo autor em <https://lourencogabriel.dev/downloads/assinaturas-gabriel.zip>. O ZIP, o catálogo e o `LEIA-ME.md` original permanecem em `origem/`. O arquivo `selecao.json` registra a procedência e o SHA-256 dos recursos selecionados. A apresentação está em `../assinatura.html`.

## Por que esta assinatura

O próprio `LEIA-ME.md` informa que o Monograma GL é a assinatura adotada no portfólio e o destina a projetos profissionais. Sua geometria simples permite reconhecer a autoria sem competir com o W de percurso, símbolo do produto. As variantes monocromáticas funcionam sobre o papel e o floresta definidos no branding e preservam o lima como destaque do WMS.

O catálogo contém nove marcas. Três têm relação mais direta com o contexto do projeto:

| Opção | Leitura para o WMS | Decisão |
| --- | --- | --- |
| 01 — Monograma GL | Continuidade com o portfólio, assinatura profissional e forma simples | Escolhida para o projeto inteiro |
| 02 — Code GL | Referência explícita ao desenvolvimento, especialmente apropriada a ferramentas e documentação técnica | Alternativa coerente, com mais detalhes em tamanhos pequenos |
| 05 — Conexão | Relação com dados, integrações e automação | Alternativa coerente, visualmente próxima do tema de trajetos já presente no símbolo do produto |

As demais opções do catálogo estão associadas a aprendizado, jogos, aventura e esporte. São referências pessoais válidas; a escolha para este sistema prioriza continuidade profissional e simplicidade. Não houve pesquisa com usuários nem pontuação quantitativa de preferência: trata-se de uma seleção de design baseada no material fornecido.

## Recursos preservados

Os seis arquivos em `selecionada/` são cópias byte a byte dos originais:

- `signatures/01-monograma-gl-pt-light-mono.svg` — assinatura completa para fundo claro, 260 × 56.
- `signatures/01-monograma-gl-pt-dark-mono.svg` — assinatura completa para fundo escuro, 260 × 56.
- `icons/01-monograma-gl-light-mono.svg` — monograma isolado para fundo claro, canvas 64 × 64.
- `icons/01-monograma-gl-dark-mono.svg` — monograma isolado para fundo escuro, canvas 64 × 64.
- `png/01-monograma-gl-light-mono.png` — monograma original transparente, 512 × 512.
- `png/01-monograma-gl-dark-mono.png` — monograma original transparente, 512 × 512.

Não foram alterados contorno, texto, proporções, cores nem fontes dos arquivos originais. As instruções do pacote foram mantidas. Nenhuma assinatura nova foi criada para substituir a seleção.

## Dois modos de aplicação

### Assinatura completa original

Usar o SVG completo em áreas com espaço adequado, como o crédito da página pública de branding. Preferir sua largura original de **260 px** e preservar a proporção 260:56. A composição original inclui texto em Arial; preservá-la como fornecida pelo autor.

Evitar reduzir a assinatura inteira para caber em um rodapé estreito: a linha “Desenvolvido por” já é pequena no arquivo original. Em espaços menores, usar a composição responsiva a seguir.

### Crédito responsivo com o monograma escolhido

Usar o monograma isolado, preservado, com canvas de **32 px** e texto nativo em Manrope: “Desenvolvido por” e “Gabriel Lourenço”. O texto pode quebrar em duas linhas sem deformar a arte. Referência: 12–14 px para o contexto no web, 14 px no mobile, e 14–16 px para o nome.

Essa é uma composição de interface com o recurso original, não uma edição do SVG completo. O nome permanece texto real, legível por leitores de tela e sujeito à escala de texto da plataforma.

No web, o conjunto pode apontar para <https://lourencogabriel.dev/> com nome acessível “Desenvolvido por Gabriel Lourenço — abrir portfólio”, foco visível e área de interação suficiente. No mobile, preservar a semântica de autoria e a escala de texto; eventual navegação externa deverá seguir o padrão implementado no cliente.

## Onde aplicar

| Contexto | Aplicação prevista |
| --- | --- |
| Rodapé do painel web | Crédito responsivo discreto, após o conteúdo operacional |
| Rodapé da documentação pública | Crédito responsivo, com link para o portfólio |
| Acesso web | Crédito secundário ao final da composição de acesso |
| `/documentacao/branding` | Explicar a relação entre marca do produto e autoria, mostrando as variantes originais |
| Perfil / Sobre o WMS no mobile | Crédito de autoria separado da identidade do usuário autenticado |

O símbolo W identifica o produto. O Monograma GL identifica Gabriel. Não usar GL como favicon, launcher ou substituto do W; não colocar a assinatura em cada ação operacional. Frases de marca e alertas permanecem independentes do crédito.

## Fundos e contraste

Foram conferidos o primeiro plano e o texto de apoio das assinaturas originais sobre papel (`#F5F6F0`) e floresta (`#14251E`). A apresentação inclui os dois fundos e uma composição responsiva de referência. O ícone e o texto de crédito continuam usando contraste adequado, sem aplicar transparência que enfraqueça sua leitura.

As variantes originais usam suas próprias cores neutras. Não substituir esse recurso por um filtro de cor ou redesenhar o monograma para adaptá-lo à paleta.

## Integridade e continuidade

`selecao.json` contém URL, hash do ZIP, arquivos originais e hashes das cópias selecionadas. O ZIP original permanece local; nas etapas 4 e 5 serão versionados somente os recursos escolhidos que forem necessários aos clientes. As demais assinaturas não serão publicadas como se fossem recursos do produto.

As etapas de integração aplicarão a mesma seleção no web e no mobile, preservando a identidade de produto já construída e os ajustes que o autor trouxer.

## Verificação da seleção

Os seis recursos selecionados foram comparados byte a byte com as entradas do ZIP original e tiveram seus hashes conferidos. O pacote de seleção contém nove arquivos íntegros: seis recursos, estas instruções, `selecao.json` e o `LEIA-ME.md` original.

A apresentação foi verificada em Chromium por arquivo local, sem rede, nas larguras 1440, 1024, 768, 760, 390 e 320 px. Os três SVGs completos exibidos preservam a largura de 260 px, sem overflow horizontal da página. Funcionaram troca de fundo, ajuste de tamanho do nome, semântica do link de autoria e download do pacote; não houve erros JavaScript.

Contrastes calculados dos textos originais: nome/monograma claro sobre papel 13,93:1; contexto claro sobre papel 4,62:1; nome/monograma inverso sobre floresta 14,27:1; contexto inverso sobre floresta 8,13:1. São medidas dos pares de cor usados, e não uma homologação dos clientes.
