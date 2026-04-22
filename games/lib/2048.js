(function() {
    let canvas, ctx;
    let grid, score, moved;
    const size = 4;
    const width = 400;
    const cellSize = width / size;

    window.init2048 = function() {
        canvas = document.getElementById('game-canvas');
        ctx = canvas.getContext('2d');
        canvas.width = width;
        canvas.height = width;

        grid = Array(size).fill().map(() => Array(size).fill(0));
        score = 0;
        addTile();
        addTile();
        draw();

        document.addEventListener('keydown', handleInput);

        return function cleanup() {
            document.removeEventListener('keydown', handleInput);
        };
    };

    function addTile() {
        let empty = [];
        for (let r = 0; r < size; r++) {
            for (let c = 0; c < size; c++) {
                if (grid[r][c] === 0) empty.push({ r, c });
            }
        }
        if (empty.length > 0) {
            let { r, c } = empty[Math.floor(Math.random() * empty.length)];
            grid[r][c] = Math.random() < 0.9 ? 2 : 4;
        }
    }

    function draw() {
        ctx.fillStyle = '#111827';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        for (let r = 0; r < size; r++) {
            for (let c = 0; c < size; c++) {
                drawTile(r, c, grid[r][c]);
            }
        }

        const scoreEl = document.getElementById('best-score');
        if (scoreEl) scoreEl.textContent = score;
    }

    function drawTile(r, c, value) {
        const x = c * cellSize + 5;
        const y = r * cellSize + 5;
        const w = cellSize - 10;
        const h = cellSize - 10;

        ctx.fillStyle = getTileColor(value);
        ctx.beginPath();
        if (ctx.roundRect) {
            ctx.roundRect(x, y, w, h, 8);
        } else {
            ctx.rect(x, y, w, h);
        }
        ctx.fill();

        if (value !== 0) {
            ctx.fillStyle = value <= 4 ? '#1e293b' : '#f8fafc';
            ctx.font = 'bold ' + (value > 100 ? '24px' : '32px') + ' Arial';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(value, x + w / 2, y + h / 2);
        }
    }

    function getTileColor(value) {
        const colors = {
            0: '#1f2937',
            2: '#e2e8f0',
            4: '#cbd5e1',
            8: '#fca5a5',
            16: '#f87171',
            32: '#ef4444',
            64: '#dc2626',
            128: '#fde047',
            256: '#facc15',
            512: '#eab308',
            1024: '#ca8a04',
            2048: '#a16207'
        };
        return colors[value] || '#4338ca';
    }

    function handleInput(e) {
        moved = false;
        if (e.key === 'ArrowUp') move('up');
        else if (e.key === 'ArrowDown') move('down');
        else if (e.key === 'ArrowLeft') move('left');
        else if (e.key === 'ArrowRight') move('right');

        if (moved) {
            addTile();
            draw();
            if (isGameOver()) {
                alert('Game Over! Score: ' + score);
                saveScore(score);
                window.init2048();
            }
        }
    }

    function move(dir) {
        if (dir === 'left' || dir === 'right') {
            for (let r = 0; r < size; r++) {
                let row = grid[r].filter(v => v !== 0);
                if (dir === 'right') row.reverse();

                for (let i = 0; i < row.length - 1; i++) {
                    if (row[i] === row[i + 1]) {
                        row[i] *= 2;
                        score += row[i];
                        row.splice(i + 1, 1);
                        moved = true;
                    }
                }

                while (row.length < size) row.push(0);
                if (dir === 'right') row.reverse();

                if (JSON.stringify(grid[r]) !== JSON.stringify(row)) moved = true;
                grid[r] = row;
            }
        } else {
            for (let c = 0; c < size; c++) {
                let col = [];
                for (let r = 0; r < size; r++) if (grid[r][c] !== 0) col.push(grid[r][c]);
                if (dir === 'down') col.reverse();

                for (let i = 0; i < col.length - 1; i++) {
                    if (col[i] === col[i + 1]) {
                        col[i] *= 2;
                        score += col[i];
                        col.splice(i + 1, 1);
                        moved = true;
                    }
                }

                while (col.length < size) col.push(0);
                if (dir === 'down') col.reverse();

                for (let r = 0; r < size; r++) {
                    if (grid[r][c] !== col[r]) moved = true;
                    grid[r][c] = col[r];
                }
            }
        }
    }

    function isGameOver() {
        for (let r = 0; r < size; r++) {
            for (let c = 0; c < size; c++) {
                if (grid[r][c] === 0) return false;
                if (c < size - 1 && grid[r][c] === grid[r][c + 1]) return false;
                if (r < size - 1 && grid[r][c] === grid[r + 1][c]) return false;
            }
        }
        return true;
    }

    function saveScore(s) {
        const best = localStorage.getItem('bestScore_2048') || 0;
        if (s > best) {
            localStorage.setItem('bestScore_2048', s);
        }
    }
})();
