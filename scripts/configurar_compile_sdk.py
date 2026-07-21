"""
Força compileSdk >= 36 em TODOS os subprojetos do Gradle (nosso app E
todos os plugins, como geocoding_android), editando o build.gradle(.kts)
de nível raiz (android/build.gradle ou android/build.gradle.kts).

Por que isso é necessário: alguns plugins (ex: geocoding_android) têm
seu PRÓPRIO build.gradle, vindo de dentro do pacote publicado no
pub.dev — não temos como editar esse arquivo diretamente. Só editar o
build.gradle do NOSSO app (android/app/build.gradle[.kts]) não resolve,
porque cada plugin é um subprojeto Gradle separado com seu próprio
compileSdk. A forma robusta de resolver isso pra todos de uma vez é
interceptar cada subprojeto no arquivo raiz, depois que ele aplica seu
próprio plugin Android, e sobrescrever o compileSdk ali.

Roda apenas dentro do GitHub Actions, depois de `flutter create`.
"""

import pathlib
import sys

ROOT_GROOVY = pathlib.Path("android/build.gradle")
ROOT_KOTLIN = pathlib.Path("android/build.gradle.kts")

BLOCO_KOTLIN = """
// ----- Início: força compileSdk alto em todos os subprojetos -----
// Adicionado automaticamente pelo script configurar_compile_sdk.py.
// Alguns plugins (ex: geocoding_android) exigem compileSdk >= 34, mas
// o valor padrão do Flutter pode ficar abaixo disso. Usamos
// `afterEvaluate` (em vez de `plugins.withId`) de propósito: o
// `plugins.withId` dispara no momento em que o plugin é aplicado, ANTES
// do restante do build.gradle do próprio plugin rodar — e como esse
// build.gradle define seu próprio `compileSdk = flutter.compileSdkVersion`
// logo em seguida, ele sobrescrevia o nosso valor de volta. Com
// `afterEvaluate`, nosso ajuste roda por último, depois de tudo.
subprojects {
    val aplicarCompileSdk: () -> Unit = {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let {
            it.compileSdk = 36
        }
    }
    // Alguns subprojetos já podem estar avaliados nesse ponto (o próprio
    // template do Flutter usa `evaluationDependsOn(":app")`, o que força
    // avaliação antecipada de alguns módulos). Nesse caso, `afterEvaluate`
    // lança exceção — então aplicamos direto quando isso acontece.
    try {
        afterEvaluate { aplicarCompileSdk() }
    } catch (e: Exception) {
        aplicarCompileSdk()
    }
}
// ----- Fim -----
"""

BLOCO_GROOVY = """
// ----- Início: força compileSdk alto em todos os subprojetos -----
// Ver comentário equivalente na versão Kotlin DSL deste script.
subprojects {
    afterEvaluate { project ->
        if (project.hasProperty('android')) {
            project.android.compileSdkVersion 36
        }
    }
}
// ----- Fim -----
"""


def main() -> None:
    if ROOT_KOTLIN.exists():
        caminho = ROOT_KOTLIN
        bloco = BLOCO_KOTLIN
    elif ROOT_GROOVY.exists():
        caminho = ROOT_GROOVY
        bloco = BLOCO_GROOVY
    else:
        print(
            f"ERRO: nem {ROOT_GROOVY} nem {ROOT_KOTLIN} foram encontrados.",
            file=sys.stderr,
        )
        sys.exit(1)

    conteudo = caminho.read_text(encoding="utf-8")

    if "configurar_compile_sdk.py" in conteudo:
        print("compileSdk global já configurado, nada a fazer.")
        return

    # IMPORTANTE: inserimos no INÍCIO do arquivo (mas depois de eventuais
    # linhas `import`, que em Kotlin DSL precisam ficar sempre primeiro).
    # O template do Flutter tem uma linha (`evaluationDependsOn(":app")`)
    # que força uma avaliação antecipada de alguns subprojetos. Se o
    # nosso bloco `afterEvaluate` for registrado depois dela no arquivo,
    # chega tarde demais pra alguns módulos (que já terminaram de
    # avaliar) e o Gradle recusa com "already evaluated".
    linhas = conteudo.split("\n")
    posicao_insercao = 0
    for i, linha in enumerate(linhas):
        if linha.strip().startswith("import ") or linha.strip() == "":
            posicao_insercao = i + 1
        else:
            break

    linhas.insert(posicao_insercao, bloco)
    conteudo = "\n".join(linhas)
    caminho.write_text(conteudo, encoding="utf-8")
    print(f"compileSdk global (36) forçado para todos os subprojetos em {caminho}.")


if __name__ == "__main__":
    main()
