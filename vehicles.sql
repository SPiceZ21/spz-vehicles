CREATE TABLE IF NOT EXISTS vehicle_customizations (
  id         INT         AUTO_INCREMENT PRIMARY KEY,
  player_id  INT         NOT NULL,
  model      VARCHAR(64) NOT NULL,
  preset     JSON        NOT NULL,
  updated_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,

  UNIQUE KEY uq_player_model (player_id, model),
  FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE,
  INDEX idx_player (player_id)
);
