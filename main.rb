require 'dxruby'
require_relative '../ruby-ev3/lib/ev3'
Window.caption = "group1"
include Math

x0 = 480
y0 = 300

LEFT_MOTOR         = "A"
COLOR_SENSOR_MOTOR = "B"
ARM_MOTOR          = "C"
RIGHT_MOTOR        = "D"
GYRO_SENSOR        = "2"
DISTANCE_SENSOR    = "3"
COLOR_SENSOR       = "4"
PORT               = "COM3"
MOTOR_SPEED        = 50

BLACK  = 1
BLUE   = 2
GREEN  = 3
YELLOW = 4
RED    = 5
WHITE  = 6
BROWN  = 7

def on_road?(brick)
  6 != brick.get_sensor(COLOR_SENSOR, 2)
end

def straight(brick, motors, sleep_time)
  brick.start(35, *motors) 
  sleep sleep_time
  brick.stop(true, *motors)
end

def turn(brick, motor, sleep_time)
  brick.start(35, motor) 
  sleep sleep_time
  brick.stop(true, motor)
end

def back(brick, motors, sleep_time)
  brick.reverse_polarity(*motors)  
  brick.start(MOTOR_SPEED, *motors)
  sleep sleep_time
  brick.stop(true, *motors)
  brick.reverse_polarity(*motors)
end

def sensor_angle_turn(brick, sensor_angle_value, motor_directions) 
  if motor_directions[COLOR_SENSOR_MOTOR]
    brick.start(MOTOR_SPEED, LEFT_MOTOR)
    sleep 1
    brick.stop(true, LEFT_MOTOR)
  else
    brick.start(MOTOR_SPEED, RIGHT_MOTOR)
    sleep 1
    brick.stop(true, RIGHT_MOTOR)
  end
end

def reverse(brick, motors, motor_directions)
  brick.reverse_polarity(*motors)
  motors.each {|key, value|
    motor_directions[key] = !motor_directions[key]
  }
end

begin
  puts "starting..."
  font = Font.new(32)
  brick = EV3::Brick.new(EV3::Connections::Bluetooth.new(PORT))
  brick.connect
  puts "connected..."
  
  motors = [LEFT_MOTOR, RIGHT_MOTOR]
  # モーターの回転方向を初期化
  
  motor_directions = {LEFT_MOTOR => true, RIGHT_MOTOR => true, COLOR_SENSOR_MOTOR => true}
  #trueがセンサー方向、falseが超音波方向
  #COLOR_SENSOR_MOTORは、時計まわりがtrue, 逆時計まわりがfalse

  brick.clear_all #reset(*motors)
  sensor_angle = brick.get_count(COLOR_SENSOR_MOTOR)
  #COLOR_SENSOR_MOTORの角度で初期化
  sensor_angle_value = 10
  #頭を回す角度 
  sensor_direction = true
  #color_sensor_motorが前回、どちらに向いていたか。trueが正の方向

  red_count    = 0
  yellow_count = 0
  reverse(brick, motors, motor_directions)
  #なぜか後ろに進むので、モーター反転
  white_count = 0
  catching = false
  turning = true
  turning_for_target = false
  target_degrees = []
  target_degree = 0
  prev_degree = 0
  go_for_target = false
  start_time = Time.now
  distance = 20

  Window.loop do
    break if Input.keyDown?( K_SPACE )
    Window.draw_font(100, 100, red_count.to_s, font)
    Window.draw_font(50, 50, yellow_count.to_s, font)
    puts motor_directions

    # 白以外だった場合進んでCOLOR_SENSOR_MOTORを0度まで回す
    if on_road?(brick)
      case brick.get_sensor(COLOR_SENSOR, 2)
        when RED
          red_count += 1
        when BROWN
          sensor_angle_turn(brick, sensor_angle_value, motor_directions) 
          back(brick, motors, 0.2) if sensor_angle_value.between?(-20, 20)
        
        when YELLOW
          until catching 
            yellow_count += 1
            sensor_angle_turn(brick, sensor_angle_value, motor_directions)
            reverse(brick, [LEFT_MOTOR], motor_directions)
            until distance < 5
              straight(brick, motors, 0.2)
              distance = brick.get_sensor(DISTANCE_SENSOR, 0)
            end
            brick.step_velocity(20, 170, 0, ARM_MOTOR)
            brick.motor_ready(ARM_MOTOR)
            reverse(brick, [LEFT_MOTOR], motor_directions)
            brick.reverse_polarity(ARM_MOTOR) #
            catching = true
          end
        when BLUE
          # reverse(brick, [LEFT_MOTOR], motor_directions)
          # straight(brick, motors, 1)
          # brick.step_velocity(20, -170, 0, ARM_MOTOR)
          # reverse(brick, [LEFT_MOTOR], motor_directions)
        when GREEN
        when BLACK
          white_count = 0
        end

      brick.step_velocity(10, 0, sensor_angle * -1, COLOR_SENSOR_MOTOR)
      sensor_angle = 0
      sleep 0.2 
      # sensor_angle_turn(brick, sensor_angle_value, motor_directions) 
      straight(brick, motors, 0.2)
      white_count = 0
    else
    #白だった場合、Color_sensor_motorを動かし、フラグを立てて、黒の方向に動く
      until on_road?(brick) 
        #線までsensor_angle_value首を振って、振り切ると符号反転
        unless sensor_direction 
          sensor_angle_value *= -1 
          !sensor_direction
        end
        # 前回のsensorの向きが負だと、負方向から首を振り始める
	      
        if sensor_angle.between?(70, 90) || sensor_angle.between?(-90, -70) 
		      sensor_angle_value *= -1
          reverse(brick, [COLOR_SENSOR_MOTOR], motor_directions)
          white_count += 1
        end
        # 70~90度になると正負反転する。
        # white_countで、白の読みすぎを防ぎたい。

        if white_count > 5
          back(brick, motors, 2)
          white_count = 0
        end
        #white_countが4以上になると、バックしてカウント初期化。

        brick.step_velocity(MOTOR_SPEED, 0, sensor_angle_value, COLOR_SENSOR_MOTOR)
        sleep 0.1
        brick.stop(true, COLOR_SENSOR_MOTOR)
        sensor_angle += sensor_angle_value
        #首を振って現在角度を保つ処理
      end

      #sensor_angleが正だと、フラグを消す
      !sensor_direction  if sensor_angle
      reverse(brick, [COLOR_SENSOR_MOTOR], motor_directions)
      sensor_angle_turn(brick, sensor_angle_value, motor_directions)

      white_count += 1
    end
  end
rescue
  p $!
  p $@
# 終了処理は必ず実行する
ensure
  if brick
    brick.step_velocity(10, 0, sensor_angle * -1, COLOR_SENSOR_MOTOR)
    brick.run_forward(*motors)
    # reverse(brick, [LEFT_MOTOR], motor_directions)
    puts "closing..."
    brick.stop(false, *motors)
    brick.clear_all
    brick.disconnect
    puts "finished..."
  end
end
