function theta = angle_solver(R_complex, mode)
    if nargin < 2 || strcmpi(mode, 'atan2')
        theta = atan2(imag(R_complex), real(R_complex));
        return;
    end

    x = real(R_complex);
    y = imag(R_complex);
    quad_offset = 0;
    if x < 0
        x = -x;
        y = -y;
        quad_offset = sign(imag(R_complex)) * pi;
        if quad_offset == 0
            quad_offset = pi;
        end
    end
    low  = -pi/2;
    high =  pi/2;
    for iter = 1:16
        mid = 0.5 * (low + high);
        im_rot = y * cos(mid) - x * sin(mid);
        if im_rot >= 0
            low = mid;
        else
            high = mid;
        end
    end
    theta = 0.5 * (low + high) + quad_offset;
end
