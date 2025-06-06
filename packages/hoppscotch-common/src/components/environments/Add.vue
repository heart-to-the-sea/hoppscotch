<template>
  <HoppSmartModal
    v-if="show"
    :title="t('environment.set_as_environment')"
    @close="hideModal"
  >
    <template #body>
      <div class="flex flex-1 flex-col space-y-4">
        <div class="ml-2 flex items-center space-x-8">
          <label for="name" class="min-w-[2.5rem] font-semibold">{{
            t("environment.name")
          }}</label>
          <input
            v-model="editingName"
            type="text"
            :placeholder="t('environment.variable')"
            class="input"
          />
        </div>
        <div class="ml-2 flex items-center space-x-8">
          <label for="value" class="min-w-[2.5rem] font-semibold">{{
            t("environment.value")
          }}</label>
          <SmartEnvInput
            v-model="editingValue"
            type="text"
            class="input"
            :placeholder="t('environment.value')"
          />
        </div>
        <div class="ml-2 flex items-center space-x-8">
          <label for="scope" class="min-w-[2.5rem] font-semibold">
            {{ t("environment.scope") }}
          </label>
          <div
            class="relative flex flex-1 flex-col rounded border border-divider focus-visible:border-dividerDark"
          >
            <EnvironmentsSelector v-model="scope" :is-scope-selector="true" />
          </div>
        </div>
        <div v-if="replaceWithVariable" class="mt-3 flex space-x-2">
          <div class="min-w-[4rem]" />
          <HoppSmartCheckbox
            :on="replaceWithVariable"
            :title="t('environment.replace_with_variable')"
            @change="replaceWithVariable = !replaceWithVariable"
          />
          <label for="replaceWithVariable">
            {{ t("environment.replace_with_variable") }}</label
          >
        </div>
      </div>
    </template>
    <template #footer>
      <span class="flex space-x-2">
        <HoppButtonPrimary
          :label="t('action.save')"
          outline
          @click="addEnvironment"
        />
        <HoppButtonSecondary
          :label="t('action.cancel')"
          outline
          filled
          @click="hideModal"
        />
      </span>
    </template>
  </HoppSmartModal>
</template>

<script lang="ts" setup>
import { useService } from "dioc/vue"
import * as TE from "fp-ts/TaskEither"
import { pipe } from "fp-ts/function"
import { ref, watch } from "vue"
import { useI18n } from "~/composables/i18n"
import { useToast } from "~/composables/toast"
import { GQLError } from "~/helpers/backend/GQLClient"
import { updateTeamEnvironment } from "~/helpers/backend/mutations/TeamEnvironment"
import { getEnvActionErrorMessage } from "~/helpers/error-messages"
import {
  setGlobalEnvVariables,
  updateEnvironment,
} from "~/newstore/environments"
import { CurrentValueService } from "~/services/current-environment-value.service"
import { RESTTabService } from "~/services/tab/rest"
import { Scope } from "./Selector.vue"
import { GlobalEnvironment } from "@hoppscotch/data"

const t = useI18n()
const toast = useToast()

const tabs = useService(RESTTabService)
const currentEnvironmentValueService = useService(CurrentValueService)

const props = defineProps<{
  show: boolean
  position: { top: number; left: number }
  name: string
  value: string
}>()

const emit = defineEmits<{
  (e: "hide-modal"): void
}>()

const hideModal = () => {
  emit("hide-modal")
}

watch(
  () => props.show,
  (newVal) => {
    if (!newVal) {
      scope.value = {
        type: "global",
        variables: [],
      }
      replaceWithVariable.value = false
      editingName.value = ""
      editingValue.value = ""
    }
    editingName.value = props.name
    editingValue.value = props.value
  }
)

const scope = ref<Scope>({
  type: "global",
  variables: [],
})

const replaceWithVariable = ref(false)

const editingName = ref(props.name)
const editingValue = ref(props.value)

const addEnvironment = async () => {
  if (!editingName.value) {
    toast.error(`${t("environment.invalid_name")}`)
    return
  }
  if (scope.value.type === "global") {
    const newVariables = [
      ...scope.value.variables,
      {
        key: editingName.value,
        initialValue: editingValue.value,
        currentValue: "",
        secret: false,
      },
    ]

    const newEnv: GlobalEnvironment = {
      v: 2,
      variables: newVariables,
    }

    setGlobalEnvVariables(newEnv)
    currentEnvironmentValueService.addEnvironmentVariable("Global", {
      key: editingName.value,
      currentValue: editingValue.value,
      isSecret: false,
      varIndex: scope.value.variables.length,
    })
    toast.success(`${t("environment.updated")}`)
  } else if (scope.value.type === "my-environment") {
    const newVariables = [
      ...scope.value.environment.variables,
      {
        key: editingName.value,
        initialValue: editingValue.value,
        currentValue: "",
        secret: false,
      },
    ]

    const newEnv = {
      ...scope.value.environment,
      variables: newVariables,
    }

    updateEnvironment(scope.value.index, newEnv)
    currentEnvironmentValueService.addEnvironmentVariable(
      scope.value.environment.id,
      {
        key: editingName.value,
        currentValue: editingValue.value,
        isSecret: false,
        varIndex: scope.value.environment.variables.length,
      }
    )
    toast.success(`${t("environment.updated")}`)
  } else {
    const newVariables = [
      ...scope.value.environment.environment.variables,
      {
        key: editingName.value,
        initialValue: editingValue.value,
        currentValue: "",
        secret: false,
      },
    ]

    await pipe(
      updateTeamEnvironment(
        JSON.stringify(newVariables),
        scope.value.environment.id,
        scope.value.environment.environment.name
      ),
      TE.match(
        (err: GQLError<string>) => {
          console.error(err)
          toast.error(t(getEnvActionErrorMessage(err)))
        },
        () => {
          if (scope.value.type === "team-environment") {
            currentEnvironmentValueService.addEnvironmentVariable(
              scope.value.environment.id,
              {
                key: editingName.value,
                currentValue: editingValue.value,
                isSecret: false,
                varIndex:
                  scope.value.environment.environment.variables.length - 1,
              }
            )
          }
          hideModal()
          toast.success(`${t("environment.updated")}`)
        }
      )
    )()
  }
  if (replaceWithVariable.value) {
    //replace the current tab endpoint with the variable name with << and >>
    const variableName = `<<${editingName.value}>>`
    //replace the currenttab endpoint containing the value in the text with variablename
    tabs.currentActiveTab.value.document.request.endpoint =
      tabs.currentActiveTab.value.document.request.endpoint.replace(
        editingValue.value,
        variableName
      )
  }

  hideModal()
}
</script>
