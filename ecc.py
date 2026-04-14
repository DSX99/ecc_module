from tinyec import ec
import random
from fastecdsa.curve import Curve
from fastecdsa.point import Point

def point_add_affine(p1_x,p1_y,p2_x,p2_y,a,p):
    if p1_x == None:
        return p2_x,p2_y
    if p2_x == None:
        return p1_x,p1_y
    m = (p2_y-p1_y)*(inverse(p2_x-p1_x,p))%p
    p3_x = (m**2-p1_x-p2_x)%p
    p3_y = (-(p1_y+m*(p3_x-p1_x)))%p

    return (p3_x,p3_y)

def point_add_jacobian(p1_x,p1_y,p1_z,p2_x,p2_y,p2_z,p):
    if p1_x == 0:
        return p2_x,p2_y,p2_z
    if p2_x == 0:
        return p1_x,p1_y,p1_z
    #here i define z=1, but for chained operations we should carry z between all operations
    u1 = (p1_x*p2_z**2)%p
    u2 = (p2_x*p1_z**2)%p
    s1 = (p1_y*p2_z**3)%p
    s2 = (p2_y*p1_z**3)%p
    r = (s1 - s2)%p
    h = (u1 -u2)%p
    g = (h**3)%p
    v = (u1*h**2)%p
    p3_x = (r**2 + g - 2*v)%p
    p3_y = (r*(v-p3_x) - s1*g)%p
    p3_z = (p1_z*p2_z*h)%p

    return p3_x, p3_y, p3_z
    # p3_x = (p3_x*inverse(p3_z,p)**2)%p
    # p3_y = (p3_y*inverse(p3_z,p)**3)%p
    # return p3_x,p3_y

def point_double_jacobian(p1_x,p1_y,p1_z,p):
    M=(3*(p1_x-p1_z**2)*(p1_x+p1_z**2))%p
    T=(p1_y**4)%p
    S=(4*p1_x*p1_y**2)%p
    p3_x=(M**2-2*S)%p
    p3_y=(M*(S-p3_x)-8*T)%p
    p3_z=(2*p1_y*p1_z)%p

    return p3_x, p3_y, p3_z    
    # p3_x = (p3_x*inverse(p3_z,p)**2)%p
    # p3_y = (p3_y*inverse(p3_z,p)**3)%p
    # return p3_x,p3_y

def point_mult_jacobian(p1_x,p1_y,p,a):
    buf_x=p1_x
    buf_y=p1_y
    buf_z=1
    ans_x=0
    ans_y=0
    ans_z=1
    while a!=0:
        if(a&1):
            ans_x, ans_y, ans_z = point_add(ans_x,ans_y,ans_z,buf_x,buf_y,buf_z,p)
        a=a>>1
        buf_x, buf_y, buf_z = point_double(buf_x,buf_y,buf_z,p)
            
    inv = inverse(ans_z,p)
    x = (ans_x*inv**2)%p
    y = (ans_y*inv**3)%p
    return x,y

def modmul(a,b,p,p_not,r):
    #here values of n_not will actualy be precomputed and same everywhere
    t = (a*b) %r
    m=(t*p_not)%r
    u=(a*b+m*p)//r
    if(u>p):
        return u-p
    else:
        return u

def point_add_affine_montgomery(p1_x,p1_y,p2_x,p2_y,a,p):
    if p1_x == None:
        return p2_x,p2_y
    if p2_x == None:
        return p1_x,p1_y
    inv = inverse((p2_x-p1_x)%p,p)
    r=1<<5
    r_not = inverse(r,p)
    p_not = (r*r_not-1)//p
    
    y1_m = (p1_y * r) %p
    y2_m = (p2_y * r) %p
    x1_m = (p1_x * r) %p
    x2_m = (p2_x * r) %p
    inv_m = (inv * r) %p
    
    m = modmul((y2_m - y1_m)%p,inv_m,p,p_not,r)
    p3_x = (modmul(m,m,p,p_not,r)-x1_m-x2_m)%p
    p3_y = (-(y1_m + modmul(m,(p3_x-x1_m),p,p_not,r)))%p
    
    p3_x = modmul(p3_x,1,p,p_not,r)
    p3_y = modmul(p3_y,1,p,p_not,r)
    
    return (p3_x,p3_y)
    
def point_add_jacobian_montgomery(p1_x,p1_y,p1_z,p2_x,p2_y,p2_z,a,p):
    if p1_x == None:
        return p2_x,p2_y
    if p2_x == None:
        return p1_x,p1_y
    #here i define z=1, but for chained operations we should carry z between all operations
    r = 1<<256
    
    r_not = inverse(r,p)    
    p_not = (r*r_not-1)//p
    
    x1 = p1_x*r%p
    x2 = p2_x*r%p
    y1 = p1_y*r%p
    y2 = p2_y*r%p
    z1 = p1_z*r%p
    z2 = p2_z*r%p
    
    q = (p,p_not,r)

    z1_sq = modmul(z1,z1,*q)
    z2_sq = modmul(z2,z2,*q)
    z1_tr = modmul(z1_sq,z1,*q)
    z2_tr = modmul(z2_sq,z2,*q)

    u1 = modmul(x1,z2_sq,*q)
    u2 = modmul(x2,z1_sq,*q)
    s1 = modmul(y1,z2_tr,*q)
    s2 = modmul(y2,z1_tr,*q)

    r = (s1 - s2) %p
    h = (u1 - u2) %p
    
    h_sq = modmul(h,h,*q)
    g = modmul(h_sq,h,*q)
    v = modmul(u1,h_sq,*q)
    
    p3_x = (modmul(r,r,*q) + g - (v+v))%p
    p3_y = (modmul(r,(v-p3_x),*q) - modmul(s1,g,*q))%p
    p3_z = modmul(modmul(z1,z2,*q),h,*q)
    
    print(f"p3_x: {hex(p3_x)}")
    print(f"p3_y: {hex(p3_y)}")
    print(f"p3_z: {hex(p3_z)}")

    # u1 = (p1_x*p2_z**2)%p
    # u2 = (p2_x*p1_z**2)%p
    # s1 = (p1_y*p2_z**3)%p
    # s2 = (p2_y*p1_z**3)%p
    # r = (s1 - s2)%p
    # h = (u1 -u2)%p
    # g = (h**3)%p
    # v = (u1*h**2)%p
    # p3_x = (r**2 + g - 2*v)%p
    # p3_y = (r*(v-p3_x) - s1*g)%p
    # p3_z = (p1_z*p2_z*h)%p
    
    p3_x = modmul(p3_x, 1, *q)
    p3_y = modmul(p3_y, 1, *q)
    p3_z = modmul(p3_z, 1, *q)
    
    p3_x = (p3_x*inverse(p3_z**2,p))%p
    p3_y = (p3_y*inverse(p3_z**3,p))%p

    # Constants and Montgomery setup
    print(f"p1_z: {p1_z}")
    print(f"p2_z: {p2_z}")
    print(f"r_not: {hex(r_not)}")
    print(f"p_not: {hex(p_not)}")

    # Transformed coordinates (Montgomery domain)
    print(f"x1: {hex(x1)}")
    print(f"x2: {hex(x2)}")
    print(f"y1: {hex(y1)}")
    print(f"y2: {hex(y2)}")
    print(f"z1: {hex(z1)}")
    print(f"z2: {hex(z2)}")
    print(f"q: ({hex(q[0])}, {hex(q[1])}, {hex(q[2])})")

    # Intermediate powers and slopes
    print(f"z1_sq: {hex(z1_sq)}")
    print(f"z2_sq: {hex(z2_sq)}")
    print(f"z1_tr: {hex(z1_tr)}")
    print(f"z2_tr: {hex(z2_tr)}")
    print(f"u1: {hex(u1)}")
    print(f"u2: {hex(u2)}")
    print(f"s1: {hex(s1)}")
    print(f"s2: {hex(s2)}")

    # Differences and curve arithmetic
    print(f"r (slope numerator): {hex(r)}")
    print(f"h (slope denominator): {hex(h)}")
    print(f"h_sq: {hex(h_sq)}")
    print(f"g: {hex(g)}")
    print(f"v: {hex(v)}")

    # Final Result (P3)
    print(f"p3_x: {hex(p3_x)}")
    print(f"p3_y: {hex(p3_y)}")
    print(f"p3_z: {hex(p3_z)}")
    
    return p3_x,p3_y
    
def point_double_jacobian_montgomery(p1_x,p1_y,a,p):

    #here i define z=1, but for chained operations we should carry z between all operations
    r = 1<<256
    
    p1_z = 1
    
    r_not = inverse(r,p)    
    p_not = (r*r_not-1)//p
    
    a = a*r%p
    p1_x = p1_x*r%p
    p1_y = p1_y*r%p
    p1_z = p1_z*r%p
    
    q = (p,p_not,r)
    
    # Point Doubling in Montgomery Domain
    # Input: p1_x, p1_y, p1_z, a, q (p, p_not, r)

    # Pre-calculate squares and higher powers
    x1_sq = modmul(p1_x, p1_x, *q)
    y1_sq = modmul(p1_y, p1_y, *q)
    z1_sq = modmul(p1_z, p1_z, *q)

    z1_qu = modmul(z1_sq, z1_sq, *q) # z1^4
    y1_qu = modmul(y1_sq, y1_sq, *q) # y1^4 (T)

    # M = 3*x1^2 + a*z1^4
    three_x1_sq = (x1_sq + x1_sq + x1_sq) % p
    a_z1_qu = modmul(a, z1_qu, *q)
    m = (three_x1_sq + a_z1_qu) % p

    # T = y1^4
    t = y1_qu

    # S = 4*x1*y1^2
    x1_y1_sq = modmul(p1_x, y1_sq, *q)
    s = (x1_y1_sq + x1_y1_sq) % p
    s = (s + s) % p # Doubling twice to get 4x

    # x3 = M^2 - 2S
    m_sq = modmul(m, m, *q)
    two_s = (s + s) % p
    p3_x = (m_sq - two_s) % p

    # y3 = M(S - x3) - 8T
    s_minus_x3 = (s - p3_x) % p
    m_s_x3 = modmul(m, s_minus_x3, *q)
    eight_t = (t + t) % p
    eight_t = (eight_t + eight_t) % p
    eight_t = (eight_t + eight_t) % p # Doubling three times to get 8t
    p3_y = (m_s_x3 - eight_t) % p

    # z3 = 2*y1*z1
    y1_z1 = modmul(p1_y, p1_z, *q)
    p3_z = (y1_z1 + y1_z1) % p
    
    print("--- Point Doubling Results ---")
    print(f"M: {hex(m)}")
    print(f"T: {hex(t)}")
    print(f"S: {hex(s)}")
    print(f"8T: {hex(eight_t)}")
    print(f"M_sq: {hex(m_sq)}")
    print(f"s_x3: {hex(s_minus_x3)}")
    print(f"M_s_x3: {hex(m_s_x3)}")
    print(f"p3_x (Double): {hex(p3_x)}")
    print(f"p3_y (Double): {hex(p3_y)}")
    print(f"p3_z (Double): {hex(p3_z)}")
    
    p3_x = modmul(p3_x, 1, *q)
    p3_y = modmul(p3_y, 1, *q)
    p3_z = modmul(p3_z, 1, *q)
    
    p3_x = (p3_x*inverse(p3_z**2,p))%p
    p3_y = (p3_y*inverse(p3_z**3,p))%p

    return p3_x,p3_y
    

def inverse(a,p):
    return pow(a,p-2,p)    

def montgomery_ladder_step(XQP, XRP, M, YP, p):
    """
    Performs a single step of the Montgomery ladder based on the provided 
    ladder state and field prime p.
    """
    
    # 1. YR_bar = YP + 2 * M * XRP
    YR_bar = (YP + 2 * M * XRP) % p
    
    # 2. E = XQP - XRP
    E = (XQP - XRP) % p
    
    # 3. F = YR_bar * E
    F = (YR_bar * E) % p
    
    # 4. G = E^2
    G = pow(E, 2, p)
    
    # 5. XRP_prime = XRP * G
    XRP_prime = (XRP * G) % p
    
    # 6. H = YR_bar^2
    H = pow(YR_bar, 2, p)
    
    # 7. M_prime = M * F
    M_prime = (M * F) % p
    
    # 8. YP_prime = YP * F * G
    YP_prime = (YP * F * G) % p
    
    # 9. K = H + M_prime
    K = (H + M_prime) % p
    
    # 10. L = K + M_prime
    L = (K + M_prime) % p
    
    # 11. M_double_prime = XRP_prime - K
    M_double_prime = (XRP_prime - K) % p
    
    # 12. XSP = H * L
    XSP = (H * L) % p
    
    # 13. XTP = XRP_prime^2 + YP_prime
    XTP = (pow(XRP_prime, 2, p) + YP_prime) % p
    
    # 14. YP_double_prime = YP_prime * H
    YP_double_prime = (YP_prime * H) % p
    
    return XSP, XTP, M_double_prime, YP_double_prime
    
def run_testbench():    
    p = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD97
    a = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD94
    b = 0xA6
    m = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6C611070995AD10045841B09B761B893
    q = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6C611070995AD10045841B09B761B893
    x = 0x01
    y = 0x008D91E471E0989CDA27DF505A453F2B7635294F2DDF23E3B122ACC99C9E9F1E14
    
    gost_256_paramB = Curve(
        'id-tc26-gost-3410-2012-256-paramSetB', 
        p, a, b, q, x, y
    )
    
    G = gost_256_paramB.G
    
    k = random.randint(0,q-1)
    
    answ = k*G
    
    
    for h in range(10):
        RE = h*G
        print(hex(RE.x))
    
    # k = 1<<257 + (k-1<<257)%p but first step alreadt done R=2P Q=R
    k = (k - (1<<256))%q
    
    Z_sq = ((2*G.y)**2)%p
    mZ = (3*G.x**2+a)%p
    Xrp = ((mZ**2)-3*G.x*Z_sq)%p
    Y = (Z_sq**2)%p
    
    XQP = 0
    XRP = (Xrp)%p
    M = (mZ)%p
    YP = (Y)%p
    
    print(hex(XQP),hex(XRP),hex(M),hex(YP), bin(k))
    
    for i in range(256):
        bit = (k >> (255 - i)) & 1
        if bit == 1:
            XQP, XRP, M, YP = montgomery_ladder_step(XQP, XRP, M, YP, p)
        else:
            XRP, XQP, M, YP = montgomery_ladder_step(XRP, XQP, M, YP, p)
            
    print(hex(XQP),hex(XRP),hex(M),hex(YP))
            
    numer = (2*G.y*(M**2 - XQP - XRP))%p
    denom = (3*G.x * (YP))%p
            
    Z_inv = ((numer)*inverse(denom,p))%p

    x_q = (G.x + XQP*Z_inv*Z_inv)%p

    print(hex(answ.x), hex(x_q))
    
    assert x_q == answ.x

if __name__ == "__main__":
    run_testbench()