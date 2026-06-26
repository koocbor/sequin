<script lang="ts">
  import { Input } from "$lib/components/ui/input";
  import {
    Card,
    CardContent,
    CardHeader,
    CardTitle,
  } from "$lib/components/ui/card";
  import { Label } from "$lib/components/ui/label";
  import type { NatsJetstreamConsumer } from "$lib/consumers/types";
  import FormItem from "$lib/components/ui/form-item.svelte";
  import FormErrorMessage from "$lib/components/ui/form-error-message.svelte";
  import FormToggleVisibilityButton from "$lib/components/ui/form-toggle-visibility-button.svelte";
  import { Switch } from "$lib/components/ui/switch";
  import DynamicRoutingForm from "$lib/consumers/DynamicRoutingForm.svelte";

  export let form: NatsJetstreamConsumer;
  export let errors: any = {};
  export let functions: Array<any> = [];
  export let refreshFunctions: () => void;
  export let functionRefreshState: "idle" | "refreshing" | "done" = "idle";

  let showPassword = false;

  function togglePasswordVisibility() {
    showPassword = !showPassword;
  }
</script>

<Card>
  <CardHeader>
    <CardTitle>NATS JetStream Configuration</CardTitle>
  </CardHeader>
  <CardContent class="flex flex-col gap-4">
    <FormItem>
      <Label for="host">Host</Label>
      <Input id="host" bind:value={form.sink.host} placeholder="localhost" />
      {#if errors.sink?.host}
        <FormErrorMessage>{errors.sink.host}</FormErrorMessage>
      {/if}
    </FormItem>

    <FormItem>
      <Label for="port">Port</Label>
      <Input
        id="port"
        type="number"
        bind:value={form.sink.port}
        placeholder="4222"
      />
      {#if errors.sink?.port}
        <FormErrorMessage>{errors.sink.port}</FormErrorMessage>
      {/if}
    </FormItem>

    <FormItem>
      <Label for="stream_name">Stream Name</Label>
      <Input
        id="stream_name"
        bind:value={form.sink.stream_name}
        placeholder="(optional)"
      />
      {#if errors.sink?.stream_name}
        <FormErrorMessage>{errors.sink.stream_name}</FormErrorMessage>
      {/if}
    </FormItem>

    <FormItem>
      <Label for="domain">Domain</Label>
      <Input
        id="domain"
        bind:value={form.sink.domain}
        placeholder="(optional)"
      />
      {#if errors.sink?.domain}
        <FormErrorMessage>{errors.sink.domain}</FormErrorMessage>
      {/if}
    </FormItem>

    <FormItem>
      <Label for="publish_timeout_ms">Publish Timeout (ms)</Label>
      <Input
        id="publish_timeout_ms"
        type="number"
        bind:value={form.sink.publish_timeout_ms}
        placeholder="5000"
      />
      {#if errors.sink?.publish_timeout_ms}
        <FormErrorMessage>{errors.sink.publish_timeout_ms}</FormErrorMessage>
      {/if}
    </FormItem>

    <FormItem>
      <div class="flex items-center gap-2">
        <Switch
          id="tls"
          checked={form.sink.tls}
          onCheckedChange={(checked) => {
            form.sink.tls = checked;
          }}
        />
        <Label for="tls">TLS</Label>
      </div>
      {#if errors.sink?.tls}
        <FormErrorMessage>{errors.sink.tls}</FormErrorMessage>
      {/if}
    </FormItem>

    <FormItem>
      <Label for="username">Username</Label>
      <Input
        id="username"
        bind:value={form.sink.username}
        placeholder="(optional)"
      />
      {#if errors.sink?.username}
        <FormErrorMessage>{errors.sink.username}</FormErrorMessage>
      {/if}
    </FormItem>

    <FormItem>
      <Label for="password">Password</Label>
      <div class="relative">
        <Input
          id="password"
          type={showPassword ? "text" : "password"}
          bind:value={form.sink.password}
          placeholder="(optional)"
          data-1p-ignore
          autocomplete="off"
        />
        <FormToggleVisibilityButton
          isVisible={showPassword}
          label="password"
          onToggleVisibility={togglePasswordVisibility}
        />
      </div>
      {#if errors.sink?.password}
        <FormErrorMessage>{errors.sink.password}</FormErrorMessage>
      {/if}
    </FormItem>

    <FormItem>
      <Label for="jwt">JWT</Label>
      <div class="relative">
        <Input
          id="jwt"
          type={showPassword ? "text" : "password"}
          bind:value={form.sink.jwt}
          placeholder="(optional)"
          data-1p-ignore
          autocomplete="off"
        />
        <FormToggleVisibilityButton
          isVisible={showPassword}
          label="jwt"
          onToggleVisibility={togglePasswordVisibility}
        />
      </div>
      {#if errors.sink?.jwt}
        <FormErrorMessage>{errors.sink.jwt}</FormErrorMessage>
      {/if}
    </FormItem>

    <FormItem>
      <Label for="nkey_seed">NKey Seed</Label>
      <div class="relative">
        <Input
          id="nkey_seed"
          type={showPassword ? "text" : "password"}
          bind:value={form.sink.nkey_seed}
          placeholder="(optional)"
          data-1p-ignore
          autocomplete="off"
        />
        <FormToggleVisibilityButton
          isVisible={showPassword}
          label="nkey_seed"
          onToggleVisibility={togglePasswordVisibility}
        />
      </div>
      {#if errors.sink?.nkey_seed}
        <FormErrorMessage>{errors.sink.nkey_seed}</FormErrorMessage>
      {/if}
    </FormItem>
  </CardContent>
</Card>

<Card>
  <CardHeader>
    <CardTitle>Routing</CardTitle>
  </CardHeader>
  <CardContent>
    <DynamicRoutingForm
      bind:form
      {functions}
      {refreshFunctions}
      bind:functionRefreshState
      routedSinkType="nats_jetstream"
      {errors}
    />
  </CardContent>
</Card>
