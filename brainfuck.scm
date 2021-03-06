(use gauche.termios)

;; http://d.hatena.ne.jp/rui314/20070319/p1
;; 端末を非カノニカルモードに変更して1文字を読む手続き。
;; リターンするまえに端末のモードを元に戻す。
(define (read-single-char port)
  (let* ((attr (sys-tcgetattr port))
         (lflag (slot-ref attr 'lflag)))
    (dynamic-wind
      (lambda ()
        (slot-set! attr 'lflag (logand lflag (lognot ICANON)))
        (sys-tcsetattr port TCSAFLUSH attr))
      (lambda ()
        (read-char port))
      (lambda ()
        (slot-set! attr 'lflag lflag)
        (sys-tcsetattr port TCSANOW attr)))))

;;インクリメント
(define (add1 n)
    (+ n 1))

;;デクリメント
(define (sub1 n)
    (- n 1))

;;carを繰り返す
(define (skip-car lat n)
    (cond
        ((null? lat) '())
        ((zero? n) lat)
        (else
            (skip-car (cdr lat) (sub1 n)))))


;;環境から特定箇所の値を取得
(define (pick-up env pos)
    (define (iter-pick lat n)
        (cond
            ((null? lat) 0)
            ((zero? n) (car lat))
            (else
                (iter-pick (cdr lat) (sub1 n)))))
    (iter-pick env pos))

;;環境の特定の場所に値を書き込んだ新しいリストを作成する
(define (drop-off env val pos)
    (define (list-format lat n)
        (cond
            ((zero? n) lat)
            ((< n (length lat)) lat)
            (else
                (list-format (append lat (cons 0 '())) (sub1 n)))))
    (define (iter-drop lat val n)
        (cond
            ((not (list? lat)) (iter-drop (cons lat '()) val n))
            ((not (number? n)) lat)
            (else
                (cond
                    ((zero? n) (cons val (cdr lat)))
                    ((zero? (length lat))
                        (iter-drop (cons 0 lat) val (sub1 n)))
                    (else
                        (cons (car lat) (iter-drop (cdr lat) val (sub1 n))))))))
    (iter-drop (list-format env pos) val pos))

(define (loop-eval lat loop-lat env p)
    (cond
        ((null? lat) env)
        (else
            (cond
                ((zero? (pick-up env p))
                    (brainfuck-eval (skip-car lat (length loop-lat)) env p))
                (else
                    (loop-eval lat loop-lat (brainfuck-eval loop-lat env p) p))))))


;;[]で囲まれた範囲を返す。ネストしている場合はその部分を含んで返却する
(define (loop-line lat)
    (define (loop-line-iter lat nest-cnt)
        ;(print (car lat))
        (cond
            ((null? lat) n)
            (else
                (cond
                    ((string=? "[" (car lat))
                        (cons (car lat) (loop-line-iter (cdr lat) (add1 nest-cnt))))
                    ((string=? "]" (car lat))
                        (cond
                            ((zero? nest-cnt) (cons (car lat) '()))
                            (else
                                (cons (car lat) (loop-line-iter (cdr lat) (sub1 nest-cnt))))))
                    (else
                        (cons (car lat) (loop-line-iter (cdr lat) nest-cnt)))))))
    (loop-line-iter lat -1))

;;eval
(define (brainfuck-eval lat env p)
    ;(print "lat=" lat)
    (cond
        ((null? lat) env)
        (else
            (cond
                ((string=? ">" (car lat))
                    (brainfuck-eval (cdr lat) env (add1 p)))
                ((string=? "<" (car lat))
                    (cond
                        ((zero? p)
                            (brainfuck-eval (cdr lat) env p))
                        (else
                            (brainfuck-eval (cdr lat) env (sub1 p)))))
                ((string=? "+" (car lat))
                    (brainfuck-eval
                        (cdr lat) (drop-off env (add1 (pick-up env p)) p) p))
                ((string=? "-" (car lat))
                    (brainfuck-eval
                        (cdr lat) (drop-off env (sub1 (pick-up env p)) p) p))
                ((string=? "." (car lat))
                    (print "[ " (string (integer->char (pick-up env p))) " ] (" (pick-up env p) ")")
                    (brainfuck-eval (cdr lat) env p))
                ((string=? "," (car lat))
                    (brainfuck-eval
                        (cdr lat) (drop-off env (char->integer (read-single-char (current-input-port))) p) p))
                ((string=? "[" (car lat))
                    (loop-eval lat (cdr (loop-line lat)) env p))
                (else
                    (brainfuck-eval (cdr lat) env p))))))

(define (brainfuck line)
    (print "line=" line)
    (cond
        ((null? line) '())
        (else
            (brainfuck-eval (map string (string->list line)) '(0) 0))))

;(print (brainfuck ".+++.>++.<.++++++++++.>.>>>>.+++++++++.<<<<<<<<<<<.++++++++++++++++++++++."))
;(print "env= " (brainfuck ",."))
;(print "env= " (brainfuck "+++++++++[>++++++++>+++++++++++>+++++<<<-]>.>++.+++++++..+++.>-.------------.<++++++++.--------.+++.------.--------.>+."))



;;=============================================

(use gauche.parseopt)

(define (read-file file-name)
  (with-input-from-file file-name
    (lambda ()
      (let loop((ls1 '()) (c (read-char)))
	(if (eof-object? c)
	    (list->string (reverse ls1))
	    (loop (cons c ls1) (read-char)))))))

(define main
    (lambda (args)
        (let-args (cdr args)
            ((infile "f=s" #f)
             (instr "i=s" #f))
            (cond
              ((not (equal? #f instr))
                  (brainfuck instr))
              (else
                  (brainfuck (read-file infile)))))))

