const loginForm = document.getElementById('login-form');
const loginMsg = document.getElementById('login-msg');
const appSection = document.getElementById('app-section');
const uploadForm = document.getElementById('upload-form');
const uploadResult = document.getElementById('upload-result');
const docsTableBody = document.querySelector('#docs-table tbody');
const summaryDiv = document.getElementById('summary');

let loggedIn = false;

async function api(path, opts={}) {
  const res = await fetch(path, opts);
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = new FormData(loginForm);
  try {
    const data = await api('/api/login', { method: 'POST', body: form });
    loggedIn = true;
    loginMsg.textContent = `Hello, ${data.user.username}`;
    document.getElementById('login-section').style.display = 'none';
    appSection.style.display = 'block';
    await loadDocs();
  } catch (err) {
    loginMsg.textContent = 'Login failed';
  }
});

async function loadDocs() {
  const data = await api('/api/documents');
  docsTableBody.innerHTML = '';
  for (const d of data.items) {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${d.id}</td>
      <td>${d.filename}</td>
      <td>${d.size_bytes}</td>
      <td>${new Date(d.created_at).toLocaleString()}</td>
      <td>
        <button data-id="${d.id}" class="summ">Summarize</button>
        <button data-id="${d.id}" class="delete">Delete</button>
      </td>`;
    docsTableBody.appendChild(tr);
  }
  docsTableBody.querySelectorAll('button.summ').forEach(btn => {
    btn.addEventListener('click', async () => {
      summaryDiv.textContent = 'Summarizing...';
      const id = btn.getAttribute('data-id');
      const data = await api(`/api/document/${id}/summary`);
      summaryDiv.textContent = data.summary;
    });
  });
  docsTableBody.querySelectorAll('button.delete').forEach(btn => {
    btn.addEventListener('click', async () => {
      const id = btn.getAttribute('data-id');
      if (confirm(`Are you sure you want to delete document ${id}?`)) {
        try {
          await api(`/api/document/${id}`, { method: 'DELETE' });
          await loadDocs();
        } catch (err) {
          alert('Failed to delete document');
        }
      }
    });
  });
}

uploadForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = new FormData(uploadForm);
  uploadResult.textContent = 'Uploading and summarizing...';
  try {
    const data = await api('/api/upload', { method: 'POST', body: form });
    uploadResult.textContent = `Summary for ${data.filename}:\n\n${data.summary}`;
    await loadDocs();
  } catch (err) {
    uploadResult.textContent = 'Upload failed';
  }
});