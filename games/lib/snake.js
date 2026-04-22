(function() {
    let canvas, ctx;
    let snake, food, dx, dy, score, gameInterval;
    const box = 20;

    window.initSnake = function() {
        canvas = document.getElementById('game-canvas');
        ctx = canvas.getContext('2d');
        canvas.width = 400;
        canvas.height = 400;

        snake = [{ x: 10 * box, y: 10 * box }];
        food = {
            x: Math.floor(Math.random() * 19 + 1) * box,
            y: Math.floor(Math.random() * 19 + 1) * box
        };
        dx = box;
        dy = 0;
        score = 0;

        document.addEventListener('keydown', changeDirection);
        if (gameInterval) clearInterval(gameInterval);
        gameInterval = setInterval(draw, 100);

        return function cleanup() {
            clearInterval(gameInterval);
            document.removeEventListener('keydown', changeDirection);
        };
    };

    function changeDirection(event) {
        const LEFT_KEY = 37;
        const RIGHT_KEY = 39;
        const UP_KEY = 38;
        const DOWN_KEY = 40;

        const keyPressed = event.keyCode;
        const goingUp = dy === -box;
        const goingDown = dy === box;
        const goingRight = dx === box;
        const goingLeft = dx === -box;

        if (keyPressed === LEFT_KEY && !goingRight) {
            dx = -box;
            dy = 0;
        }
        if (keyPressed === UP_KEY && !goingDown) {
            dx = 0;
            dy = -box;
        }
        if (keyPressed === RIGHT_KEY && !goingLeft) {
            dx = box;
            dy = 0;
        }
        if (keyPressed === DOWN_KEY && !goingUp) {
            dx = 0;
            dy = box;
        }
    }

    function draw() {
        ctx.fillStyle = 'black';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        for (let i = 0; i < snake.length; i++) {
            ctx.fillStyle = (i === 0) ? '#4f46e5' : '#818cf8';
            ctx.fillRect(snake[i].x, snake[i].y, box, box);
            ctx.strokeStyle = 'black';
            ctx.strokeRect(snake[i].x, snake[i].y, box, box);
        }

        ctx.fillStyle = '#ef4444';
        ctx.fillRect(food.x, food.y, box, box);

        let snakeX = snake[0].x;
        let snakeY = snake[0].y;

        snakeX += dx;
        snakeY += dy;

        if (snakeX === food.x && snakeY === food.y) {
            score++;
            food = {
                x: Math.floor(Math.random() * 19 + 1) * box,
                y: Math.floor(Math.random() * 19 + 1) * box
            };
        } else {
            snake.pop();
        }

        let newHead = { x: snakeX, y: snakeY };

        if (snakeX < 0 || snakeX >= canvas.width || snakeY < 0 || snakeY >= canvas.height || collision(newHead, snake)) {
            clearInterval(gameInterval);
            saveScore(score);
            alert('Game Over! Score: ' + score);
            window.initSnake(); // Restart
            return;
        }

        snake.unshift(newHead);

        ctx.fillStyle = 'white';
        ctx.font = '20px Arial';
        ctx.fillText('Score: ' + score, 10, 25);
    }

    function collision(head, array) {
        for (let i = 0; i < array.length; i++) {
            if (head.x === array[i].x && head.y === array[i].y) return true;
        }
        return false;
    }

    function saveScore(s) {
        const best = localStorage.getItem('bestScore_snake') || 0;
        if (s > best) {
            localStorage.setItem('bestScore_snake', s);
            const scoreEl = document.getElementById('best-score');
            if (scoreEl) scoreEl.textContent = s;
        }
    }
})();
