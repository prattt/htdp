#lang racket
(require lang/htdp-advanced)
(require htdp/draw)

;; build-board : N (N N  ->  boolean)  ->  board
;; to create a board of size n x n, 
;; fill each position with indices i and j with (f i j)
(define (build-board n f)
  (build-vector n (lambda (i)
                    (build-vector n (lambda (j)
                                      (f i j))))))

;; board-ref : board N N  ->  boolean
;; to access a position with indices i, j on a-board
(define (board-ref a-board i j)
  (vector-ref (vector-ref a-board i) j))

;; threatened? posn posn -> boolean
;; Determines if the given board-posn is threated by the queen-posn
(define (threatened? queen-posn board-posn)
  (local ((define q-x (posn-x queen-posn))
          (define q-y (posn-y queen-posn))
          (define b-x (posn-x board-posn))
          (define b-y (posn-y board-posn)))
    (or (= q-x b-x)
        (= q-y b-y)
        (= (abs (- q-x b-x)) (abs (- q-y b-y))))))


;; table-for-all : (vectorof (vectorfo X)) (X N N -> void)
;; Applies the given action to all elements of the table
(define (table-for-all T action)
  (vec-for-all T (lambda (vec row)
                   (vec-for-all vec (lambda (val col) (action val row col))))))
;; vec-for-all : (vectorof X) (X N -> (void))
;; Applies the given action to all elements of the vector
(define (vec-for-all V action)
  (local
      ((define (for-all-aux idx)
         (cond
          [(zero? idx) (void)]
          [else (begin (vector-set! V (sub1 idx)
                                    (action (vector-ref V (sub1 idx))
                                            (sub1 idx)))
                       (for-all-aux (sub1 idx)))])))
    (begin (for-all-aux (vector-length V)) V)))


;; A chess-board CB is a (vectorof (vectorof boolean))
;; such that all vectors have the same size.
;; make-chess-board : N  ->  CB
(define (make-chess-board m)
  (build-vector m (lambda (i) (build-vector m (lambda (j) true)))))

(define BOARD-SIZE 4)
(define TILE-SIZE 75)
(define PIECE-SIZE 30)
(define THREAT-SIZE 5)
(define DELAY 0.45)

;; chess-board : N -> service-manager
;; A state representation of the chessboard that stores the number.
;; Takes in a natural number and gives back a status manager.
(define (chess-board n)
  (local ((define board (make-chess-board n))
          (define placed-queens empty)


          ;; place-queen : N N  ->  void
          ;; effect: to set those fields in CB to false that are threatened by 
          ;; a queen on row i, column j
          (define (place-queen i j)
            (begin (set! placed-queens (cons (make-posn i j) placed-queens))
                   (table-for-all board (lambda (val row col)
                                          (if (threatened? (make-posn i j) (make-posn row col))
                                              (begin (draw-piece THREAT-SIZE 'red row col) false) val)))
                   (draw-piece PIECE-SIZE 'green i j) (sleep-for-a-while DELAY)))

          ;; unplace-queen : N N -> void
          ;; effect: to set those fields in CB to false that were threatened by 
          ;; a queen on row i, column j
          (define (unplace-queen i j)
            (begin (set! placed-queens (remove-element (make-posn i j) placed-queens))
                   (table-for-all board (lambda (value row col)
                                          (cond
                                           [(threatened? (make-posn i j) (make-posn row col))
                                            (local ((define threat (not (ormap (lambda (i) (threatened? i (make-posn row col))) placed-queens))))
                                              (cond
                                               [threat (begin (clear-piece THREAT-SIZE row col) threat)]
                                               [else threat]))]
                                           [else value])))
                   (draw-piece PIECE-SIZE 'red i j)
                   (sleep-for-a-while DELAY)
                   (draw-piece PIECE-SIZE 'green i j)
                   (clear-piece PIECE-SIZE i j)))
                   
          (define (log x) (begin (pretty-print x) x))

          ;; remove-element : X (listof X) -> (listof X)
          ;; Removes a given element from a list
          (define (remove-element x lst)
            (foldl (lambda (i j)
                     (cond
                      [(equal? i x) j]
                      [else (cons i j)])) empty lst))
          ;; reset-board! : table -> void
          ;; Resets all the positions of the board
          ;; to be available or true
          (define (reset-board!)
            (table-for-all board (lambda (V i j) true)))

          (define (placement n)
            (cond
             [(= n 0) board]
             [else (place-queens n 0 0)]))
          
          (define (place-queens n i j)
            (cond
             [(>= i (vector-length board)) false]
             [(>= j (vector-length board)) (place-queens n (add1 i) 0)]
             [else (cond
                    [(false? (board-ref board i j)) (place-queens n i (add1 j))]
                    ;; Found a free space
                    [else (begin (place-queen i j)
                                 (local
                                     ((define a-try (placement (sub1 n))))
                                   (cond
                                    [(false? a-try) (begin (unplace-queen i j)
                                                           (place-queens n i (add1 j)))]
                                    [else a-try])))])]))
          
          (define (pretty-representation b)
            (cond
             [(false? b) false]
             [else (pretty-print (build-board (vector-length b) (lambda (i j) 
                                                                  (cond
                                                                   [(board-ref b i j) '-]
                                                                   [(queen-present? i j) 'Q]
                                                                   [else 'a]))))]))
          
          (define (queen-present? i j)
            (ormap (lambda (q) (equal? q (make-posn i j))) placed-queens))
          
          (define (service-manager msg)
            (cond
             [(symbol=? msg 'place) place-queen]
             [(symbol=? msg 'unplace) unplace-queen]
             [(symbol=? msg 'reset) (reset-board!)]
             [(symbol=? msg 'queen-locations) placed-queens]
             [(symbol=? msg 'present?) queen-present?]
             [(symbol=? msg 'n-queens) (lambda (n) (pretty-representation (placement n)))]
             [else (error 'chessboard-with-state "Unknown message")])))
    service-manager))

(define (draw-checkerboard size n)
  (cond
   [(= n 0) true]
   [else (and (draw-black-rectangle-row size
                                        (* size (- BOARD-SIZE n))
                                        (if (even? n) 0 size)
                                        (/ BOARD-SIZE 2))
              (draw-checkerboard size (sub1 n)))]))

;; row-of-posns : number number number number -> (listof posn)
;; Creates a row of positions from the given inputs
(define (row-of-posns x displacement offset count)
  (local ((define (displace d) (make-posn x (+ offset (* displacement d)))))
    (map displace (build-list count (lambda (n) n)))))

(define (draw-black-rectangle-row size x-location offset count)
  (andmap (lambda (i) (draw-solid-rect i size size 'black)) (row-of-posns x-location (* 2 size) offset count)))

(define (draw-piece size color i j)
  (local ((define (draw-circle p) (draw-solid-disk p size color)))
    (draw-circle (make-posn (+ (* TILE-SIZE j) (/ TILE-SIZE 2)) (+ (* TILE-SIZE i) (/ TILE-SIZE 2))))))


(define (clear-piece size i j)
  (cond
   [(even? (+ i j)) (draw-piece PIECE-SIZE 'black i j)]
   [else (draw-piece PIECE-SIZE 'white i j)]))

(start (* BOARD-SIZE TILE-SIZE) (* BOARD-SIZE TILE-SIZE))
(draw-checkerboard TILE-SIZE BOARD-SIZE)
(define board (chess-board BOARD-SIZE))
((board 'n-queens) BOARD-SIZE)
