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

---

# Phoenix File Uploads

Use this skill before implementing ANY file upload functionality.

## RULES — Follow these with no exceptions

1. **Use manual uploads (NOT `auto_upload: true`)** for form submission patterns
2. **Always add upload directory to `static_paths()`** — files won't be accessible without this
3. **Handle upload errors** — display `error_to_string/1` output in templates
4. **Validate file types server-side** — never trust client MIME types
5. **Restart server after changing `static_paths()`** — changes don't apply until restart


## Implementation Workflow

Follow these steps in order:

1. **Add `uploads` to `static_paths()`** — see Static Paths Configuration below
2. **Restart the server** — `static_paths()` changes require a full restart to take effect
3. **Add `allow_upload/3` in `mount/3`** — configure accepted types, entry limits, and file size
4. **Implement `handle_event("validate", ...)`** — required to trigger change tracking
5. **Implement `handle_event("save", ...)`** — consume entries, create directories, copy files
6. **Add the upload form to your template** — include drop target, previews, and error display
7. **Verify** — confirm upload directory exists, files are saved, and URLs resolve correctly


## Upload Configuration

### Manual Upload (Recommended)

```elixir
allow_upload(:upload_name,
  accept: ~w(.jpg .jpeg .png .pdf),
  max_entries: 10,
  max_file_size: 10_000_000
)
```


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


## Static Paths Configuration

```elixir
# lib/my_app_web endpoint.ex
def static_paths do
  ~w(assets fonts images favicon.ico robots.txt uploads)
end
```

---

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Use `auto_upload: true` with form submission | Use manual uploads and consume on `save` |
| Forget to add `uploads` to `static_paths()` | Add the dir to `static_paths()` (files 404 without it) |
| Expect `static_paths()` edits to hot-reload | Restart the server after changing `static_paths()` |
| Trust the client-reported MIME type | Validate file types server-side |
| Keep the client's original filename | Generate a safe filename (e.g. `Ecto.UUID.generate/0` + ext) |
| Swallow upload errors silently | Render `error_to_string/1` per entry in the template |
| Skip the `"validate"` handler | Implement `handle_event("validate", ...)` to track changes |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| phoenix-liveview-essentials | phoenix-uploads | testing-essentials |
| apply-phoenix-liveview-conventions | phoenix-uploads | security-essentials |

**Companion skills:**
- `phoenix-liveview-essentials` — LiveView lifecycle and form binding
- `security-essentials` — validating and safely serving user-supplied files
- `testing-essentials` — exercising uploads with `Phoenix.LiveViewTest`
