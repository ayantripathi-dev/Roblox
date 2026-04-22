(function() {
    let canvas, ctx;
    let grid, piece, score, gameInterval;
    const ROWS = 20;
    const COLS = 10;
    const BLOCK_SIZE = 20;

    const SHAPES = [
        [[1, 1, 1, 1]], // I
        [[1, 1], [1, 1]], // O
        [[0, 1, 0], [1, 1, 1]], // T
        [[1, 1, 0], [0, 1, 1]], // S
        [[0, 1, 1], [1, 1, 0]], // Z
        [[1, 0, 0], [1, 1, 1]], // J
        [[0, 0, 1], [1, 1, 1]]  // L
    ];

    const COLORS = ['#00ffff', '#ffff00', '#800080', '#00ff00', '#ff0000', '#0000ff', '#ff7f00'];

    window.initTetris = function() {
        canvas = document.getElementById('game-canvas');
        ctx = canvas.getContext('2d');
        canvas.width = COLS * BLOCK_SIZE;
        canvas.height = ROWS * BLOCK_SIZE;

        grid = Array(ROWS).fill().map(() => Array(COLS).fill(0));
        score = 0;
        spawnPiece();

        document.addEventListener('keydown', handleKey);
        if (gameInterval) clearInterval(gameInterval);
        gameInterval = setInterval(update, 500);

        return function cleanup() {
            clearInterval(gameInterval);
            document.removeEventListener('keydown', handleKey);
        };
    };

    function spawnPiece() {
        const typeId = Math.floor(Math.random() * SHAPES.length);
        piece = {
            pos: { x: Math.floor(COLS / 2) - 1, y: 0 },
            shape: SHAPES[typeId],
            color: COLORS[typeId]
        };
        if (collide()) {
            gameOver();
        }
    }

    function rotate(matrix) {
        return matrix[0].map((_, i) => matrix.map(row => row[i]).reverse());
    }

    function collide() {
        for (let y = 0; y < piece.shape.length; y++) {
            for (let x = 0; x < piece.shape[y].length; x++) {
                if (piece.shape[y][x] !== 0) {
                    let ny = piece.pos.y + y;
                    let nx = piece.pos.x + x;
                    if (ny >= ROWS || nx < 0 || nx >= COLS || (ny >= 0 && grid[ny][nx] !== 0)) return true;
                }
            }
        }
        return false;
    }

    function merge() {
        piece.shape.forEach((row, y) => {
            row.forEach((value, x) => {
                if (value !== 0) {
                    grid[piece.pos.y + y][piece.pos.x + x] = piece.color;
                }
            });
        });
    }

    function clearLines() {
        let linesCleared = 0;
        for (let y = ROWS - 1; y >= 0; y--) {
            if (grid[y].every(cell => cell !== 0)) {
                grid.splice(y, 1);
                grid.unshift(Array(COLS).fill(0));
                linesCleared++;
                y++;
            }
        }
        if (linesCleared > 0) {
            score += [0, 100, 300, 500, 800][linesCleared];
            const scoreEl = document.getElementById('best-score');
            if (scoreEl) scoreEl.textContent = score;
        }
    }

    function update() {
        piece.pos.y++;
        if (collide()) {
            piece.pos.y--;
            merge();
            clearLines();
            spawnPiece();
        }
        draw();
    }

    function draw() {
        ctx.fillStyle = '#000';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        grid.forEach((row, y) => {
            row.forEach((value, x) => {
                if (value !== 0) {
                    ctx.fillStyle = value;
                    ctx.fillRect(x * BLOCK_SIZE, y * BLOCK_SIZE, BLOCK_SIZE - 1, BLOCK_SIZE - 1);
                }
            });
        });

        if (piece) {
            ctx.fillStyle = piece.color;
            piece.shape.forEach((row, y) => {
                row.forEach((value, x) => {
                    if (value !== 0) {
                        ctx.fillRect((piece.pos.x + x) * BLOCK_SIZE, (piece.pos.y + y) * BLOCK_SIZE, BLOCK_SIZE - 1, BLOCK_SIZE - 1);
                    }
                });
            });
        }
    }

    function handleKey(e) {
        if (e.key === 'ArrowLeft') {
            piece.pos.x--;
            if (collide()) piece.pos.x++;
        } else if (e.key === 'ArrowRight') {
            piece.pos.x++;
            if (collide()) piece.pos.x--;
        } else if (e.key === 'ArrowDown') {
            update();
        } else if (e.key === 'ArrowUp') {
            const oldShape = piece.shape;
            piece.shape = rotate(piece.shape);
            if (collide()) piece.shape = oldShape;
        } else if (e.key === ' ') {
            while (!collide()) piece.pos.y++;
            piece.pos.y--;
            update();
        }
        draw();
    }

    function gameOver() {
        clearInterval(gameInterval);
        alert('Game Over! Score: ' + score);
        saveScore(score);
        window.initTetris();
    }

    function saveScore(s) {
        const best = localStorage.getItem('bestScore_tetris') || 0;
        if (s > best) {
            localStorage.setItem('bestScore_tetris', s);
        }
    }
})();
