/*
 * Copyright 2026 Mifos Initiative
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * See https://github.com/openMF/kmp-project-template/blob/main/LICENSE
 */
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Pins the key set `syncForkConfig` accepts on a `network.build_config_fields` row. A key the plugin
 * does not know used to be dropped silently, so a fork on an older build-logic declared
 * `secret_alias:` and shipped the field as "".
 */
class BuildConfigFieldKeysTest {

    @Test
    fun everyDocumentedKeyIsAccepted() {
        val row = mapOf(
            "name" to "MY_KEY",
            "from_env" to "MY_KEY",
            "secret_alias" to "proj-my-key",
            "required_in_release" to true,
            "required_prefix" to "pk_",
        )
        assertEquals(emptyList(), unknownBuildConfigFieldKeys(row))
    }

    @Test
    fun anUnknownKeyIsReported() {
        val row = mapOf("name" to "MY_KEY", "secret_alais" to "proj-my-key", "vault" to "x")
        assertEquals(listOf("secret_alais", "vault"), unknownBuildConfigFieldKeys(row))
    }
}
