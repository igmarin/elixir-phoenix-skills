---
name: phoenix-uploads
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for file upload features. Invoke before implementing upload or file serving functionality.
  Covers manual uploads, upload configuration, file validation, safe filenames, static paths,
  and template patterns.
  Trigger words: upload, file upload, allow_upload, consume_uploaded_entries, static_paths, file serving.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Phoenix File Uploads

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before implementing ANY file upload functionality.

## RULES — Follow these with no exceptions

1. **Use manual uploads (NOT `auto_upload: true`)** for form submission patterns
2. **Always add upload directory to `static_paths()`** — files won't be accessible without this
3. **Handle upload errors** — display `error_to_string/1` output in templates
4. **Create upload directories with `File.mkdir_p!`** before saving files
5. **Generate unique filenames** — prevent collisions and path traversal attacks
6. **Validate file types server-side** — never trust client MIME types
7. **Restart server after changing `static_paths()`** — changes don't apply until restart

---

## Upload Configuration

### Manual Upload (Recommended)

```elixir
allow_upload(:upload_name,
  accept: ~w(.jpg .jpeg .png .pdf),
  max_entries: 10,
  max_file_size: 10_000_000
)
```

### Auto Upload (Advanced - Use Sparingly)

Only use `auto_upload: true` when:
- Files should upload immediately on selection
- You have `handle_progress/3` callback
- You consume entries outside form submission

**Never use `auto_upload: true` with form submission patterns!**

---

## Complete Upload Pattern

### LiveView Module

```elixir
@impl true
def mount(_params, _session, socket) do
  socket =
    socket
    |> assign(:uploaded_files, [])
    |> allow_upload(:photos,
         accept: ~w(.jpg .jpeg .png),
         max_entries: 5,
         max_file_size: 10_000_000
       )

  {:ok, socket}
end

@impl true
def handle_event("validate", _params, socket) do
  {:noreply, socket}
end

@impl true
def handle_event("save", _params, socket) do
  uploaded_files =
    consume_uploaded_entries(socket, :photos, fn %{path: path}, entry ->
      dest = Path.join(["priv", "static", "uploads", safe_filename(entry.client_name)])
      File.mkdir_p!(Path.dirname(dest))
      File.cp!(path, dest)
      {:ok, ~s(/uploads/#{Path.basename(dest)})}
    end)

  {:noreply, assign(socket, :uploaded_files, uploaded_files)}
end

defp safe_filename(original_name) do
  ext = Path.extname(original_name)
  "#{Ecto.UUID.generate()}#{ext}"
end
```

### Template

```heex
<.form for={%{}} phx-submit="save" phx-change="validate" id="upload-form">
  <div phx-drop-target={@uploads.photos.ref}>
    <.live_file_input upload={@uploads.photos} />
  </div>

  <%= for entry <- @uploads.photos.entries do %>
    <div>
      <.live_img_preview entry={entry} />
      <progress value={entry.progress} max="100"><%= entry.progress %>%</progress>

      <%= for err <- upload_errors(@uploads.photos, entry) do %>
        <p class="error"><%= error_to_string(err) %></p>
      <% end %>
    </div>
  <% end %>

  <button type="submit">Upload</button>
</.form>

def error_to_string(:too_large), do: "Too large"
def error_to_string(:too_many_files), do: "Too many files"
def error_to_string(:not_accepted), do: "Unacceptable file type"
```

---

## Static Paths Configuration

```elixir
# lib/my_app_web endpoint.ex
def static_paths do
  ~w(assets fonts images favicon.ico robots.txt uploads)
end
```

---

## Common Pitfalls

❌ **Don't** use `auto_upload: true` with form submission
❌ **Don't** forget to add upload directory to `static_paths()`
❌ **Don't** trust client MIME types — validate server-side
❌ **Don't** use original filenames — generate unique names
❌ **Don't** forget to create directories with `File.mkdir_p!`
❌ **Don't** forget to restart after changing `static_paths()`

✅ **Do** use manual uploads for form patterns
✅ **Do** add upload directory to `static_paths()`
✅ **Do** generate unique filenames
✅ **Do** validate file types server-side
✅ **Do** handle and display upload errors

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **phoenix-liveview-essentials** | For LiveView lifecycle patterns |
| **testing-essentials** | For testing upload patterns |
| **security-essentials** | For file type validation |
