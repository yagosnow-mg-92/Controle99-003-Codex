# Moto Gestor 🏍️

Painel financeiro completo para motociclistas de aplicativos de entrega e
transporte (99, Uber, iFood etc.). Controla ganhos, despesas, indicadores
e desempenho da moto — 100% offline.

## ⚠️ Configuração única obrigatória: assinatura do APK

**Sem isso, você vai continuar precisando desinstalar o app a cada nova build**
(erro "conflito com pacote já existente"). Isso acontece porque, sem uma
assinatura fixa, cada build do CI assina o APK com uma chave diferente, e o
Android recusa instalar por cima uma versão com assinatura diferente da
instalada.

A correção já está pronta no código (`scripts/configurar_assinatura.py` +
workflow), falta só cadastrar 4 *secrets* no GitHub (uma única vez):

1. No repositório, vá em **Settings → Secrets and variables → Actions →
   New repository secret**.
2. Crie os 4 secrets abaixo:

   | Nome do secret | Valor |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | conteúdo do arquivo `moto_gestor_keystore_base64.txt` (uma linha enorme, cole ela inteira) |
   | `ANDROID_KEYSTORE_PASSWORD` | `MotoGestor2026!` |
   | `ANDROID_KEY_PASSWORD` | `MotoGestor2026!` |
   | `ANDROID_KEY_ALIAS` | `motogestor` |

3. Depois de criar os 4, faça um novo push — a próxima build já vai sair
   assinada com essa chave fixa, e vai continuar assim para sempre
   (guarde bem essas senhas, elas não devem mudar).

**Importante:** como você já tem o app instalado no celular com a assinatura
antiga (a "aleatória" de antes), a **primeira instalação com a nova
assinatura fixa ainda vai pedir para desinstalar** (é inevitável, é a troca
de chave). A partir dela, porém, todas as próximas atualizações vão
funcionar direto por cima, sem perder dados nunca mais.

---

## Status do desenvolvimento

- [x] Etapa 1 — Arquitetura, tema, banco de dados, tela **Dashboard**, CI/CD
- [x] Etapa 2 — Tela **Receita** (lançamento de ganhos)
- [x] Etapa 3 — Tela **Despesas** (lançamento livre com categorias)
- [x] Etapa 4 — Tela **Indicadores** (filtros e métricas avançadas)
- [x] Etapa 5 — Gráficos avançados (evolução do lucro, histórico mensal)
- [x] Etapa 6 — Tela **Configurações** (moto, combustível, metas)
- [x] Etapa 7 — Metas, alertas e funcionalidades inteligentes
- [x] Dashboard: período configurável (Dia/Semana/Mês/Personalizado, salvo) + gráfico com eixos, linha reta e valores visíveis
- [x] Modo **Corrida**: lançamento automático de receita via GPS (online → corrida → passageiro → finalizar), com rastreamento em segundo plano
- [x] Local de embarque/destino (automático via Corrida, opcional em lançamentos manuais) + menu "Mais" (Indicadores/Configurações) + revisão de contraste
- [x] Tipo de lançamento (Corrida/Deslocamento livre/Outro), km GPS arredondado, lançamento separado de deslocamento sem corrida (com endereço), visualizar/editar lançamento (duplo toque)
- [x] Lançamento automático mesmo parado (km 0, tempo de espera), horário de início/fim em todo lançamento por GPS, botão "Ver mapa do trajeto" nos lançamentos vindos da função Corrida

## Modo Corrida (rastreamento por GPS)

Nova aba dedicada a quem quer registrar os ganhos automaticamente, sem
digitar km manualmente. Funciona como uma máquina de estados:

```
Offline → [Ficar online] → Online → [Iniciar corrida] → Corrida iniciada
   ↑                          ↓                              ↓
   └──── [Ficar offline] ─────┘                      [Peguei o passageiro]
                                                              ↓
                                                       Com passageiro
                                                              ↓
                                                     [Finalizar corrida]
                                                              ↓
                                                        volta pra Online
```

- Cada clique importante grava horário, coordenadas e endereço (rua/bairro).
- Enquanto online ou em corrida, a rota é gravada por GPS — inclusive com
  a tela apagada ou o app minimizado, via serviço em primeiro plano do
  Android (notificação fixa obrigatória enquanto ativo, é uma regra do
  próprio sistema).
- Ao finalizar uma corrida, o km percorrido é calculado a partir da rota
  gravada e um lançamento de Receita é criado automaticamente.
- Ao cancelar uma corrida, é pedido o valor da taxa de deslocamento.

**Permissão necessária:** localização "Permitir o tempo todo" (não
apenas "Durante o uso"), pedida automaticamente ao tocar em "Ficar
online". Sem essa permissão em modo "sempre", o Android não garante o
rastreamento em segundo plano.

## Tecnologia

- **Flutter** (Dart) — melhor opção para performance nativa, banco local
  robusto (`sqflite`) e build headless simples via GitHub Actions.
- **SQLite** local via `sqflite` — 100% offline, arquitetura pronta para
  sincronização em nuvem futura (basta trocar a implementação do
  repositório, que fica isolada atrás de interfaces em `domain/repositories`).
- **Provider** para gerenciamento de estado (simples, testável, sem boilerplate).
- **fl_chart** para os gráficos do dashboard e indicadores.

## Arquitetura

Clean Architecture em 3 camadas:

```
lib/
├── core/            # tema, banco, utils, formatação — sem dependência de domínio
├── domain/          # entidades e contratos (repositories) — regra de negócio pura
├── data/            # implementação dos repositórios (SQLite)
└── presentation/    # telas, widgets, providers (estado)
```

A UI e o `data` dependem de `domain`, nunca o contrário. Isso permite trocar
o banco local por uma API remota no futuro sem alterar telas ou lógica de
negócio.

## Como o APK é gerado (sem instalar nada no seu PC)

Você **não precisa instalar Flutter, Android Studio, Java ou SDK**. Tudo
acontece no GitHub:

1. Faça push para a branch `main` → o workflow builda o APK e disponibiliza
   como **artefato do build** (aba *Actions* → clique no run → seção
   *Artifacts*).
2. Crie uma tag de versão (`git tag v1.0.0 && git push origin v1.0.0`) →
   o workflow além de buildar, cria automaticamente uma **Release** no
   GitHub com o APK anexado, pronto para download direto.

O workflow (`.github/workflows/build-apk.yml`) faz o seguinte:
1. Instala Java 17 e Flutter (versão fixada em `3.24.5`).
2. Roda `flutter create --platforms=android .` — isso gera a pasta
   `android/` automaticamente e sempre compatível com a versão do Flutter
   usada no CI (por isso ela **não é versionada no Git**, veja `.gitignore`).
3. Roda `flutter pub get`, `flutter analyze` e `flutter build apk --release`.
4. Publica o(s) `.apk` gerado(s).

### Como instalar o APK no celular

1. Baixe o `.apk` da aba *Actions* (artefato) ou da aba *Releases*.
2. Transfira para o celular Android.
3. Habilite "Instalar de fontes desconhecidas" nas configurações do Android.
4. Abra o arquivo `.apk` e instale.

## Rodando localmente (opcional, só se você quiser)

Não é necessário para o fluxo pedido, mas se um dia quiser rodar localmente:

```bash
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

## Design

- Tema escuro premium (Material 3), tipografia Inter (Google Fonts).
- Verde para receitas, vermelho para despesas, azul para lucro — leitura
  instantânea dos números.
- Cards com bordas suaves, gráficos com curvas suavizadas (`fl_chart`).

## Banco de dados (schema atual)

- `receitas(id, data, km_rodados, valor_recebido, valor_por_km, observacao, criado_em)`
- `despesas(id, data, categoria, valor, observacao, criado_em)`
- `categorias_despesa(nome)` — categorias reutilizáveis, extensíveis pelo usuário
- `configuracoes(chave, valor)` — moto, combustível, metas (usada a partir da Etapa 6)

---

Próxima etapa: implementação da tela **Receita**, com formulário de
lançamento e cálculo automático de valor por Km.
