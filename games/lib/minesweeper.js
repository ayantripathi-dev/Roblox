(function() {
    let canvas, ctx;
    let grid, gameOver, gameWon;
    const ROWS = 10;
    const COLS = 10;
    const MINES = 15;
    const TILE_SIZE = 40;

    window.initMinesweeper = function() {
        canvas = document.getElementById('game-canvas');
        ctx = canvas.getContext('2d');
        canvas.width = COLS * TILE_SIZE;
        canvas.height = ROWS * TILE_SIZE;

        gameOver = false;
        gameWon = false;
        grid = [];

        for (let r = 0; r < ROWS; r++) {
            grid[r] = [];
            for (let c = 0; c < COLS; c++) {
                grid[r][c] = {
                    isMine: false,
                    revealed: false,
                    flagged: false,
                    neighborCount: 0
                };
            }
        }

        let minesPlaced = 0;
        while (minesPlaced < MINES) {
            let r = Math.floor(Math.random() * ROWS);
            let c = Math.floor(Math.random() * COLS);
            if (!grid[r][c].isMine) {
                grid[r][c].isMine = true;
                minesPlaced++;
            }
        }

        for (let r = 0; r < ROWS; r++) {
            for (let c = 0; c < COLS; c++) {
                if (!grid[r][c].isMine) {
                    let count = 0;
                    for (let dr = -1; dr <= 1; dr++) {
                        for (let dc = -1; dc <= 1; dc++) {
                            let nr = r + dr, nc = c + dc;
                            if (nr >= 0 && nr < ROWS && nc >= 0 && nc < COLS && grid[nr][nc].isMine) count++;
                        }
                    }
                    grid[r][c].neighborCount = count;
                }
            }
        }

        canvas.onclick = handleClick;
        canvas.oncontextmenu = handleRightClick;
        draw();

        return function cleanup() {
            canvas.onclick = null;
            canvas.oncontextmenu = null;
        };
    };

    function handleClick(e) {
        if (gameOver || gameWon) return;
        const rect = canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const r = Math.floor(y / TILE_SIZE);
        const c = Math.floor(x / TILE_SIZE);

        reveal(r, c);
        checkWin();
        draw();
    }

    function handleRightClick(e) {
        e.preventDefault();
        if (gameOver || gameWon) return;
        const rect = canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const r = Math.floor(y / TILE_SIZE);
        const c = Math.floor(x / TILE_SIZE);

        if (!grid[r][c].revealed) {
            grid[r][c].flagged = !grid[r][c].flagged;
        }
        draw();
    }

    function reveal(r, c) {
        if (r < 0 || r >= ROWS || c < 0 || c >= COLS || grid[r][c].revealed || grid[r][c].flagged) return;

        grid[r][c].revealed = true;

        if (grid[r][c].isMine) {
            gameOver = true;
            revealAll();
            alert('BOOM! Game Over.');
            window.initMinesweeper();
            return;
        }

        if (grid[r][c].neighborCount === 0) {
            for (let dr = -1; dr <= 1; dr++) {
                for (let dc = -1; dc <= 1; dc++) {
                    reveal(r + dr, c + dc);
                }
            }
        }
    }

    function revealAll() {
        grid.forEach(row => row.forEach(tile => tile.revealed = true));
    }

    function checkWin() {
        let revealedCount = 0;
        grid.forEach(row => row.forEach(tile => { if (tile.revealed && !tile.isMine) revealedCount++; }));
        if (revealedCount === ROWS * COLS - MINES) {
            gameWon = true;
            alert('Congratulations! You cleared the field.');
            window.initMinesweeper();
        }
    }

    function draw() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        for (let r = 0; r < ROWS; r++) {
            for (let c = 0; c < COLS; c++) {
                const tile = grid[r][c];
                const x = c * TILE_SIZE;
                const y = r * TILE_SIZE;

                ctx.strokeStyle = '#374151';
                ctx.strokeRect(x, y, TILE_SIZE, TILE_SIZE);

                if (tile.revealed) {
                    ctx.fillStyle = tile.isMine ? '#ef4444' : '#1f2937';
                    ctx.fillRect(x + 1, y + 1, TILE_SIZE - 2, TILE_SIZE - 2);
                    if (!tile.isMine && tile.neighborCount > 0) {
                        ctx.fillStyle = '#94a3b8';
                        ctx.font = '20px Arial';
                        ctx.textAlign = 'center';
                        ctx.textBaseline = 'middle';
                        ctx.fillText(tile.neighborCount, x + TILE_SIZE / 2, y + TILE_SIZE / 2);
                    } else if (tile.isMine) {
                        ctx.fillStyle = 'white';
                        ctx.font = '20px Arial';
                        ctx.textAlign = 'center';
                        ctx.textBaseline = 'middle';
                        ctx.fillText('💣', x + TILE_SIZE / 2, y + TILE_SIZE / 2);
                    }
                } else {
                    ctx.fillStyle = '#4b5563';
                    ctx.fillRect(x + 1, y + 1, TILE_SIZE - 2, TILE_SIZE - 2);
                    if (tile.flagged) {
                        ctx.fillStyle = '#ef4444';
                        ctx.font = '20px Arial';
                        ctx.textAlign = 'center';
                        ctx.textBaseline = 'middle';
                        ctx.fillText('🚩', x + TILE_SIZE / 2, y + TILE_SIZE / 2);
                    }
                }
            }
        }
    }
})();
