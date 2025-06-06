<template>
  <div
    v-if="authFlowState.type === 'loading'"
    class="flex flex-col items-center"
  >
    <HoppSmartSpinner />
  </div>
  <div
    v-else-if="authFlowState.type === 'waiting'"
    class="flex flex-col items-center space-y-2"
  >
    <h2 class="text-secondaryDark font-semibold text-lg">
      Continue in your browser
    </h2>
    <p>We have opened Hoppscotch in your browser to continue your login.</p>
    <div class="py-3 flex space-x-4 items-center">
      <HoppButtonPrimary
        :label="'Open Again'"
        :icon="IconRotateCW"
        @click="openLink(authFlowState.openURL)"
      />
      <HoppButtonSecondary
        :label="'Copy Link'"
        :icon="copyIcon"
        outline
        @click="onCopyClick"
      />
    </div>
  </div>
  <div v-else class="flex flex-col items-center">
    <p>There was an error processing your login...</p>
  </div>
</template>

<script setup lang="ts">
import { invoke } from "@tauri-apps/api/core"
import { listen } from "@tauri-apps/api/event"
import { Io } from "@hoppscotch/common/kernel/io"
import { onMounted, ref } from "vue"
import IconRotateCW from "~icons/lucide/rotate-cw"
import IconLink from "~icons/lucide/link"
import IconCheck from "~icons/lucide/check"
import { copyToClipboard } from "@hoppscotch/common/helpers/utils/clipboard"
import { refAutoReset } from "@vueuse/core"
import { PersistenceService } from "@hoppscotch/common/services/persistence"
import { useService } from "dioc/vue"
import { setInitialUser } from "@platform/auth/desktop"
import { z } from "zod"

const persistenceService = useService(PersistenceService)

const DeviceTokenResponse = z.object({
  access_token: z.string(),
  refresh_token: z.string(),
})

type FlowStates =
  | { type: "loading" }
  | { type: "waiting"; openURL: string }
  | { type: "error" }

const authFlowState = ref<FlowStates>({ type: "loading" })
const copyIcon = refAutoReset(IconLink, 1000)

function onCopyClick() {
  if (authFlowState.value.type === "waiting") {
    copyIcon.value = IconCheck
    copyToClipboard(authFlowState.value.openURL)
  }
}

async function openLink(url: string) {
  await Io.openExternalLink({ url })
}

onMounted(async () => {
  const port = await invoke<number>("hopp_auth_port")

  const redirectURI = `http://localhost:${port}/device-token`
  const openURL = `${import.meta.env.VITE_BASE_URL}/device-login?redirect_uri=${encodeURIComponent(redirectURI)}`

  await openLink(openURL)
  authFlowState.value = { type: "waiting", openURL }

  await listen<string>("hopp_auth://token", async (data) => {
    console.log('hopp_auth://token', data)
    authFlowState.value = { type: "loading" }
    console.info("hopp_auth://token data", data)
    try {
      const parseResult = DeviceTokenResponse.safeParse(data.payload)
      console.info("parseResult", parseResult)

      if (!parseResult.success) {
        throw new Error("Token data returned from backend was invalid")
      }

      const tokens = parseResult.data

      await persistenceService.setLocalConfig(
        "access_token",
        tokens.access_token
      )
      await persistenceService.setLocalConfig(
        "refresh_token",
        tokens.refresh_token
      )
      await setInitialUser()
    } catch (_) {
      authFlowState.value = { type: "error" }
    }
  })
})
</script>
