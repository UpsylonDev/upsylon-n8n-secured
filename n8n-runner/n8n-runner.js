// n8n-runner.js
const express = require('express');
const { exec } = require('child_process');
const app = express();

app.use(express.json());

// Route pour exécuter des scripts npm/pnpm
app.post('/run-script', (req, res) => {
  const { script, path } = req.body; // "dev", "build", "test", etc.
  const projectPath = path || null

  if (path === null) {
    return res.status(400).json({ 
      success: false,
      error: 'Project path is required.....'
    });
    
  }
  
  console.log(`🚀 Executing: pnpm run ${script}`);
  
  const child = exec(`pnpm run ${script}`, { 
    cwd: projectPath,
    maxBuffer: 1024 * 1024 * 10 // 10MB buffer
  });
  
  let output = '';
  let errorOutput = '';
  
  child.stdout.on('data', (data) => {
    output += data;
    console.log(data.toString());
  });
  
  child.stderr.on('data', (data) => {
    errorOutput += data;
    console.error(data.toString());
  });
  
  child.on('close', (code) => {
    if (code !== 0) {
      return res.status(500).json({ 
        success: false,
        error: errorOutput,
        output: output,
        exitCode: code
      });
    }
    res.json({ 
      success: true,
      output: output,
      error: errorOutput,
      exitCode: code
    });
  });
});

// Route pour exécuter des commandes bash personnalisées
app.post('/run-command', (req, res) => {
  const { command } = req.body;
  const projectPath = 'C:/dev/experiments/DDD-NUXT/nuxt-domain-driven-design-demo';
  
  console.log(`🚀 Executing: ${command}`);
  
  exec(command, { 
    cwd: projectPath,
    maxBuffer: 1024 * 1024 * 10
  }, (error, stdout, stderr) => {
    if (error) {
      return res.status(500).json({ 
        success: false,
        error: stderr,
        message: error.message,
        output: stdout
      });
    }
    res.json({ 
      success: true,
      output: stdout,
      error: stderr 
    });
  });
});

// Route de status
app.get('/status', (req, res) =>
  res.json({ 
    status: 'running',
    project: 'nuxt-domain-driven-design-demo',
    timestamp: new Date().toISOString()
  })
);

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ n8n runner listening on http://0.0.0.0:${PORT}`);
  console.log(`📁 Project: C:/dev/experiments/DDD-NUXT/nuxt-domain-driven-design-demo`);
});